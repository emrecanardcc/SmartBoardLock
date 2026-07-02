using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace KioskLockApp.Hooks
{
    public static class DeepWindowsHooks
    {
        private const int WH_KEYBOARD_LL = 13;
        private static LowLevelProc _keyboardProc = KeyboardHookCallback;
        private static IntPtr _keyboardHookID = IntPtr.Zero;

        public static bool IsLocked = false;

        public static void InitializeHooks()
        {
            if (_keyboardHookID == IntPtr.Zero)
            {
                // SADECE klavye kancasını kuruyoruz, fareyi dokunmatik ekran için serbest bıraktık!
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
            if (nCode >= 0 && IsLocked)
            {
                // Ekran kilitliyse tüm klavye tuşlarını (Alt+Tab, Windows tuşu dahil) yut!
                return (IntPtr)1;
            }
            return CallNextHookEx(_keyboardHookID, nCode, wParam, lParam);
        }

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);
    }
}