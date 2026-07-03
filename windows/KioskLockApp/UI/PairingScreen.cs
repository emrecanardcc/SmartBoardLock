using System;

using System.Drawing;

using System.Windows.Forms;

using System.Threading.Tasks;

using Microsoft.Win32;

using KioskLockApp.Services;



namespace KioskLockApp.UI

{

    public class PairingScreen : Form

    {

        private Label lblTitle;

        private Label lblCode;

        private Label lblInstruction;

        private System.Windows.Forms.Timer pollingTimer;

        private string currentPairingCode = "";



        public PairingScreen()

        {

            this.FormBorderStyle = FormBorderStyle.None;

            this.WindowState = FormWindowState.Maximized;

            this.BackColor = Color.FromArgb(20, 20, 20); // Koyu gri arka plan

            this.TopMost = true;



            BuildUI();

            InitializePairingAsync();

        }



        private void BuildUI()

        {

            lblTitle = new Label()

            {

                Text = "AKILLI TAHTA KURULUMU",

                ForeColor = Color.White,

                Font = new Font("Arial", 36, FontStyle.Bold),

                AutoSize = true,

                Location = new Point(100, 100)

            };

            this.Controls.Add(lblTitle);



            lblInstruction = new Label()

            {

                Text = "Tahtayı aktifleştirmek için mobil uygulamadan 'Tahta Ekle' menüsüne girin\nve aşağıdaki 6 haneli eşleşme kodunu yazın.",

                ForeColor = Color.LightGray,

                Font = new Font("Arial", 20, FontStyle.Regular),

                AutoSize = true,

                Location = new Point(100, 200)

            };

            this.Controls.Add(lblInstruction);



            lblCode = new Label()

            {

                Text = "YÜKLENİYOR...",

                ForeColor = Color.Cyan,

                Font = new Font("Consolas", 80, FontStyle.Bold),

                AutoSize = true,

                Location = new Point(100, 350)

            };

            this.Controls.Add(lblCode);

        }



        private async void InitializePairingAsync()

        {

            // Benzersiz kodu veritabanına yazıp alıyoruz

            currentPairingCode = await SecureSupabase.GenerateAndRegisterPairingCodeAsync();



            if (string.IsNullOrEmpty(currentPairingCode))

            {

                lblCode.Text = "HATA OLUŞTU!";

                lblCode.ForeColor = Color.Red;

                return;

            }



            // Kodu ekrana devasa şekilde yaz

            lblCode.Text = currentPairingCode.Insert(3, " "); // Örn: 482 915 şeklinde okunaklı yazar



            // Her 3 saniyede bir telefondan onay gelmiş mi diye kontrol et

            pollingTimer = new System.Windows.Forms.Timer();

            pollingTimer.Interval = 3000;

            pollingTimer.Tick += PollingTimer_Tick;

            pollingTimer.Start();

        }



        private async void PollingTimer_Tick(object sender, EventArgs e)

        {

            pollingTimer.Stop(); // Kontrol sırasında timer'ı duraklat (çakışmayı önlemek için)



            var pairingData = await SecureSupabase.CheckPairingStatusAsync(currentPairingCode);



            if (pairingData != null)

            {

                // Eşleşme TAMAMLANDI! Verileri Registry'e kaydet

                string boardName = await SecureSupabase.GetBoardNameAsync(pairingData["board_id"]);

                SaveToRegistry(
                    pairingData["board_id"],
                    pairingData["offline_secret"],
                    boardName
                );



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



        private void SaveToRegistry(string boardId, string offlineSecret, string boardName)
        {
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\SmartBoardLock"))
            {
                key.SetValue("BoardId", boardId);
                key.SetValue("OfflineSecret", offlineSecret);
                key.SetValue("BoardName", boardName);
            }
        }

    }

}