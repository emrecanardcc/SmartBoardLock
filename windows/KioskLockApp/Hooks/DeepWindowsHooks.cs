using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace KioskLockApp.Hooks
{
    public static class DeepWindowsHooks
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_SYSKEYDOWN = 0x0104;

        private static LowLevelProc _keyboardProc = KeyboardHookCallback;
        private static IntPtr _keyboardHookID = IntPtr.Zero;

        public static bool IsLocked = false;

        public static void InitializeHooks()
        {
            if (_keyboardHookID == IntPtr.Zero)
            {
                _keyboardHookID = SetHook(_keyboardProc, WH_KEYBOARD_LL);
            }
        }

        private static IntPtr SetHook(LowLevelProc proc, int idHook)
        {
            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule curModule = curProcess.MainModule)
            {
                return SetWindowsHookEx(idHook, proc, GetModuleHandle(curModule.ModuleName), 0);
            }
        }

        private delegate IntPtr LowLevelProc(int nCode, IntPtr wParam, IntPtr lParam);

        private static IntPtr KeyboardHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && IsLocked && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN))
            {
                int vkCode = Marshal.ReadInt32(lParam);
                bool altPressed = (GetKeyState(0xA4) & 0x8000) != 0 || (GetKeyState(0xA5) & 0x8000) != 0;
                bool ctrlPressed = (GetKeyState(0xA2) & 0x8000) != 0 || (GetKeyState(0xA3) & 0x8000) != 0;

                // Engellenecek Tuşlar: Windows Tuşları, Alt+Tab, Alt+Esc, Ctrl+Esc (Başlat Menüsü), F4
                if (vkCode == 0x5B || vkCode == 0x5C || // LWIN, RWIN
                    (altPressed && vkCode == 0x09) ||   // Alt + Tab
                    (altPressed && vkCode == 0x1B) ||   // Alt + Esc
                    (altPressed && vkCode == 0x73) ||   // Alt + F4
                    (ctrlPressed && vkCode == 0x1B) ||  // Ctrl + Esc
                    (ctrlPressed && altPressed && vkCode == 0x2E)) // Ctrl + Alt + Del (Software seviyesinde)
                {
                    return (IntPtr)1; // Tuşu yut ve işletim sistemine gönderme
                }
            }
            return CallNextHookEx(_keyboardHookID, nCode, wParam, lParam);
        }

        [DllImport("user32.dll")] private static extern short GetKeyState(int nVirtKey);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelProc lpfn, IntPtr hMod, uint dwThreadId);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] public static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern IntPtr GetModuleHandle(string lpModuleName);
    }
}