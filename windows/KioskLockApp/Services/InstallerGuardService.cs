using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using KioskLockApp.UI;

namespace KioskLockApp.Services
{
    /// <summary>
    /// Akıllı tahtada yetkisiz program kurulum ve kaldırma süreçlerini (msiexec, *setup*.exe, *install*.exe, unins*.exe)
    /// donanımsal/çekirdek düzeyinde yakalayan motor.
    /// Süreç başladığı ilk milisaniyede NtSuspendProcess ile dondurulur,
    /// ekranda okul müdürü şifresi sorulur, şifre doğru ise NtResumeProcess ile devam ettirilir,
    /// şifre yanlış veya iptal ise TerminateProcess ile imha edilir.
    /// Windows Update, Windows Defender ve Sınıf360 kendi araçları beyaz liste ile korunur.
    /// </summary>
    public static class InstallerGuardService
    {
        [DllImport("ntdll.dll", SetLastError = true)]
        public static extern int NtSuspendProcess(IntPtr processHandle);

        [DllImport("ntdll.dll", SetLastError = true)]
        public static extern int NtResumeProcess(IntPtr processHandle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool TerminateProcess(IntPtr hProcess, uint uExitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CloseHandle(IntPtr hObject);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool LookupPrivilegeValue(string? lpSystemName, string lpName, out LUID lpLuid);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, [MarshalAs(UnmanagedType.Bool)] bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, uint BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [StructLayout(LayoutKind.Sequential)]
        private struct LUID
        {
            public uint LowPart;
            public int HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct TOKEN_PRIVILEGES
        {
            public uint PrivilegeCount;
            public LUID Luid;
            public uint Attributes;
        }

        private const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
        private const uint TOKEN_QUERY = 0x0008;
        private const uint SE_PRIVILEGE_ENABLED = 0x00000002;

        public const uint PROCESS_TERMINATE = 0x0001;
        public const uint PROCESS_SUSPEND_RESUME = 0x0800;
        public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        /// <summary>
        /// Süreç yönetimi için SeDebugPrivilege ayrıcalığını etkinleştirir.
        /// </summary>
        public static void EnableDebugPrivilege()
        {
            if (!OperatingSystem.IsWindows()) return;
            try
            {
                if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out IntPtr hToken))
                {
                    try
                    {
                        if (LookupPrivilegeValue(null, "SeDebugPrivilege", out LUID luid))
                        {
                            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES
                            {
                                PrivilegeCount = 1,
                                Luid = luid,
                                Attributes = SE_PRIVILEGE_ENABLED
                            };
                            AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                        }
                    }
                    finally
                    {
                        CloseHandle(hToken);
                    }
                }
            }
            catch { }
        }

        private static Thread? _guardThread;
        private static volatile bool _isRunning = false;
        private static readonly ConcurrentDictionary<int, byte> _handledProcessIds = new ConcurrentDictionary<int, byte>();
        private static readonly object _promptLock = new object();

        // Beyaz liste süreç adları (Küçük harf, uzantısız)
        private static readonly HashSet<string> WhitelistedProcessNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            // Windows Update & Servicing
            "trustedinstaller",
            "tiworker",
            "wuauclt",
            "usoclient",
            "mousocoreworker",
            "waasmedicagent",
            "sihclient",
            "dism",
            "dismhost",

            // Windows Defender & Security
            "mpsigstub",
            "msmpeng",
            "nissrv",
            "mpcmdrun",
            "smartscreen",
            "securityhealthservice",
            "securityhealthsystray",

            // Sınıf360 Ekosistemi
            "kiosklockapp",
            "watchdogservice",
            "tahtarepair",
            "tahtaupdater",
            "sinif360kaldir",
            "sinif360_kaldir",
            "sinif360kapat",
            "sinif360_kapat"
        };

        /// <summary>
        /// Bir sürecin hedef kurulum/kaldırma süreci olup olmadığını denetler.
        /// </summary>
        public static bool IsTargetProcess(string processName, string? executablePath = null)
        {
            if (string.IsNullOrWhiteSpace(processName)) return false;

            string name = processName.ToLowerInvariant();
            if (name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            {
                name = name.Substring(0, name.Length - 4);
            }

            // 1. Beyaz liste kontrolü
            if (IsWhitelisted(name, executablePath))
            {
                return false;
            }

            // 2. msiexec
            if (name == "msiexec") return true;

            // 3. *setup*
            if (name.Contains("setup")) return true;

            // 4. *install*
            if (name.Contains("install")) return true;

            // 5. unins* veya *uninstall*
            if (name.StartsWith("unins") || name.Contains("uninstall")) return true;

            // 6. Türkçe kurulum/kaldırma süreçleri (*kurulum*, *kur*, *kaldir*)
            if (name.Contains("kurulum") || name == "kur" || name.StartsWith("kur_") || name.EndsWith("_kur") || name.StartsWith("kur-") || name.EndsWith("-kur")) return true;
            if (name.Contains("kaldir")) return true;

            // 7. Paket yöneticileri (winget, choco)
            if (name == "winget" || name == "choco") return true;

            return false;
        }

        /// <summary>
        /// Sürecin veya dosya yolunun beyaz listede olup olmadığını doğrular.
        /// </summary>
        public static bool IsWhitelisted(string processName, string? executablePath = null)
        {
            string name = processName.ToLowerInvariant();
            if (name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            {
                name = name.Substring(0, name.Length - 4);
            }

            if (WhitelistedProcessNames.Contains(name))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(executablePath))
            {
                string path = executablePath.ToLowerInvariant();
                if (path.Contains(@"\microsoft\windows defender\platform\") ||
                    path.Contains(@"\windows\servicing\") ||
                    path.Contains(@"\windows\softwaredistribution\"))
                {
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// Korumayı arka planda 250 ms döngüyle başlatır.
        /// </summary>
        public static void Start()
        {
            if (_isRunning) return;
            _isRunning = true;

            // SeDebugPrivilege ayrıcalığını al ki yönetici süreçlerine de erişebilelim
            EnableDebugPrivilege();

            _guardThread = new Thread(GuardLoop)
            {
                IsBackground = true,
                Priority = ThreadPriority.AboveNormal,
                Name = "Sınıf360_InstallerGuardThread"
            };
            _guardThread.Start();
        }

        /// <summary>
        /// Korumayı durdurur.
        /// </summary>
        public static void Stop()
        {
            _isRunning = false;
            try { _guardThread?.Join(1000); } catch { }
            _guardThread = null;
        }

        private static void GuardLoop()
        {
            // Mevcut çalışan süreçleri önceden kaydet (Açılış anında var olanları hemen dondurma)
            try
            {
                foreach (var p in Process.GetProcesses())
                {
                    _handledProcessIds.TryAdd(p.Id, 0);
                    p.Dispose();
                }
            }
            catch { }

            int currentSessionId = -1;
            try
            {
                currentSessionId = Process.GetCurrentProcess().SessionId;
            }
            catch { }

            while (_isRunning)
            {
                try
                {
                    Process[] processes = Process.GetProcesses();
                    var activePids = new HashSet<int>(processes.Length);

                    foreach (var p in processes)
                    {
                        int pid = p.Id;
                        activePids.Add(pid);

                        if (!_handledProcessIds.ContainsKey(pid))
                        {
                            _handledProcessIds.TryAdd(pid, 0);

                            // Session kontrolü: Session 0 (arka plan servisleri) veya diğer kullanıcı oturumlarını atla
                            if (p.SessionId == 0 || (currentSessionId > 0 && p.SessionId != currentSessionId))
                            {
                                p.Dispose();
                                continue;
                            }

                            string pName = p.ProcessName;
                            string? mainPath = null;
                            try { mainPath = p.MainModule?.FileName; } catch { }

                            if (IsTargetProcess(pName, mainPath))
                            {
                                HandleInterceptedProcess(pid, pName);
                            }
                        }

                        p.Dispose();
                    }

                    // Kapanmış süreçleri temizle
                    foreach (var key in _handledProcessIds.Keys)
                    {
                        if (!activePids.Contains(key))
                        {
                            _handledProcessIds.TryRemove(key, out _);
                        }
                    }
                }
                catch { }

                Thread.Sleep(250);
            }
        }

        /// <summary>
        /// Hedef kurulum sürecini yakalar, dondurur ve müdür şifresini sorar.
        /// </summary>
        public static void HandleInterceptedProcess(int pid, string processName)
        {
            // Eğer aktif bir yetkilendirme penceresi (5 dakika) varsa süreci serbest bırak
            if (BoardSecurityStore.IsAuthorizedSessionActive())
            {
                return;
            }

            if (!OperatingSystem.IsWindows()) return;

            IntPtr hProcess = OpenProcess(PROCESS_SUSPEND_RESUME | PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
            if (hProcess == IntPtr.Zero) return;

            // 1. Süreci ANINDA DONDUR (Kernel NtSuspendProcess)
            int status = NtSuspendProcess(hProcess);
            if (status != 0)
            {
                CloseHandle(hProcess);
                return;
            }

            // 2. WinForms STA Thread üzerinde müdür onay iletişim kutusunu aç
            var authThread = new Thread(() =>
            {
                lock (_promptLock)
                {
                    // Şifre sorma esnasında başka bir thread yetkilendirme sağladıysa
                    if (BoardSecurityStore.IsAuthorizedSessionActive())
                    {
                        NtResumeProcess(hProcess);
                        CloseHandle(hProcess);
                        return;
                    }

                    bool authorized = false;
                    try
                    {
                        using var dialog = new InstallerAuthDialog(processName, pid);
                        var result = dialog.ShowDialog();
                        authorized = (result == DialogResult.OK && dialog.IsAuthorized);
                    }
                    catch
                    {
                        authorized = false;
                    }

                    if (authorized)
                    {
                        // 3. Şifre doğru: Süreci devam ettir
                        NtResumeProcess(hProcess);
                    }
                    else
                    {
                        // 4. Şifre yanlış / iptal: Süreci sonlandır ve kalan thread'leri serbest bırak ki zombileşmesin
                        try
                        {
                            TerminateProcess(hProcess, 1);
                            NtResumeProcess(hProcess);
                        }
                        catch { }
                    }

                    CloseHandle(hProcess);
                }
            })
            {
                IsBackground = true,
                Name = $"Sınıf360_AuthPrompt_{pid}"
            };
            authThread.SetApartmentState(ApartmentState.STA);
            authThread.Start();
        }
    }
}
