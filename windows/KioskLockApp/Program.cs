using System;
using System.Windows.Forms;
using KioskLockApp.UI;
using Microsoft.Win32; // Kayıt Defteri (Registry) işlemleri için gerekli kütüphane

namespace KioskLockApp
{
    internal class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Windows başlar başlamaz çalışması için Kayıt Defterine kanca atıyoruz
            ForceStartup();

            // Registry'den kayıtlı tahta var mı kontrol et
            string boardId = "";
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    if (key != null)
                    {
                        boardId = key.GetValue("BoardId") as string;
                    }
                }
            }
            catch
            {
                // Okuma hatası olursa boş kabul et
            }

            // Eğer boardId yoksa (veya boşsa) kurulum/eşleşme ekranını aç
            if (string.IsNullOrEmpty(boardId))
            {
                Application.Run(new PairingScreen());
            }
            else
            {
                // Kayıtlıysa doğrudan kilit ekranını aç
                Application.Run(new SecureRenderer());
            }
        }

        // --- BAŞLANGIÇTA ZORLA ÇALIŞTIRMA FONKSİYONU ---
        private static void ForceStartup()
        {
            try
            {
                // Uygulamanın bilgisayarda o an nerede çalıştığını (.exe yolunu) bul
                string appName = "AkilliTahtaKilitSistemi";
                string exePath = Application.ExecutablePath;

                // Windows'un "Otomatik Başlat" listesini aç (Düzenleme yetkisiyle)
                RegistryKey rk = Registry.CurrentUser.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", true);

                if (rk != null)
                {
                    // Eğer uygulamamız listede yoksa veya .exe'nin yeri değişmişse, listeye ZORLA YAZ!
                    if (rk.GetValue(appName) == null || rk.GetValue(appName).ToString() != exePath)
                    {
                        rk.SetValue(appName, exePath);
                    }
                }
            }
            catch
            {
                // Eğer bir yetki veya kısıtlama sorunu olursa uygulamanın çökmesini engelle
            }
        }
    }
}