using System;
using System.Drawing;
using System.Windows.Forms;
using System.Threading.Tasks;
using Microsoft.Win32;
using KioskLockApp.Services;

namespace KioskLockApp.UI
{
    public partial class PairingScreen : Form
    {
        private System.Windows.Forms.Timer pollingTimer;
        private string currentPairingCode = "";

        public PairingScreen()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.BackColor = Color.FromArgb(245, 247, 251); // Sistem Arka Planı
            this.TopMost = true;

            BuildUI(); // Tasarımı yükle
            InitializePairingAsync();
        }

        private async void InitializePairingAsync()
        {
            // Benzersiz kodu veritabanına yazıp alıyoruz
            currentPairingCode = await SecureSupabase.GenerateAndRegisterPairingCodeAsync();

            if (string.IsNullOrEmpty(currentPairingCode))
            {
                lblCode.Text = "HATA!";
                lblCode.ForeColor = Color.FromArgb(220, 38, 38); // ColDanger
                lblStatus.Text = "Bağlantı kurulamadı. Lütfen interneti kontrol edin.";
                return;
            }

            // Kodu ekrana okunaklı şekilde yaz (Örn: 482 915)
            lblCode.Text = currentPairingCode.Insert(3, " ");
            lblStatus.Text = "⏳ Telefonunuzdan onay bekleniyor...";

            // Her 3 saniyede bir telefondan onay gelmiş mi diye kontrol et
            pollingTimer = new System.Windows.Forms.Timer();
            pollingTimer.Interval = 3000;
            pollingTimer.Tick += PollingTimer_Tick;
            pollingTimer.Start();
        }

        private async void PollingTimer_Tick(object sender, EventArgs e)
        {
            pollingTimer.Stop(); // Çakışmayı önlemek için duraklat

            var pairingData = await SecureSupabase.CheckPairingStatusAsync(currentPairingCode);

            if (pairingData != null)
            {
                lblStatus.Text = "✅ Eşleşme Başarılı! Sistem başlatılıyor...";
                lblStatus.ForeColor = Color.FromArgb(16, 185, 129); // Success Green

                // Eşleşme TAMAMLANDI! Verileri çek
                string boardName = await SecureSupabase.GetBoardNameAsync(pairingData["board_id"]);
                string schoolName = await SecureSupabase.GetSchoolNameAsync(pairingData["board_id"]);

                SaveToRegistry(
                    pairingData["board_id"],
                    pairingData["offline_secret"],
                    boardName,
                    schoolName
                );

                // Kısa bir bekleme süresi (Kullanıcı başarılı yazısını görsün)
                await Task.Delay(1500);

                // Ekranı kapat ve ana kilit ekranını (SecureRenderer) başlat
                this.Hide();
                SecureRenderer lockScreen = new SecureRenderer();
                lockScreen.ShowDialog();
                this.Close();
            }
            else
            {
                // Henüz eşleşmedi, dinlemeye devam et
                pollingTimer.Start();
            }
        }

        private void SaveToRegistry(string boardId, string offlineSecret, string boardName, string schoolName)
        {
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\SmartBoardLock"))
            {
                key.SetValue("BoardId", boardId);
                key.SetValue("OfflineSecret", offlineSecret);
                key.SetValue("BoardName", boardName);
                key.SetValue("SchoolName", string.IsNullOrEmpty(schoolName) ? "Bilinmeyen Okul" : schoolName);
            }
        }
    }
}