using System;
using System.Collections.Generic;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;
using KioskLockApp.UI;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class SecureRendererLayoutTests
    {
        private static readonly Size[] TestResolutions = new[]
        {
            new Size(1024, 768),   // 4:3 Projeksiyon / Eski Küçük Ekran
            new Size(1280, 720),   // 16:9 HD 720p
            new Size(1280, 800),   // 16:10 Tablet / Tahta
            new Size(1280, 1024),  // 5:4 Eski Kare Monitör
            new Size(1366, 768),   // 16:9 Faz-1 Akıllı Tahtalar & Laptoplar
            new Size(1600, 900),   // 16:9 HD+
            new Size(1920, 1080),  // 16:9 Full HD Faz-2/Faz-3 Tahtalar
            new Size(1920, 1200),  // 16:10 WUXGA
            new Size(2560, 1440),  // 16:9 2K QHD
            new Size(3840, 2160)   // 16:9 4K UHD Yeni Nesil Etkileşimli Paneller
        };

        private void RunInSta(Action action)
        {
            Exception? threadEx = null;
            Thread t = new Thread(() =>
            {
                try
                {
                    action();
                }
                catch (Exception ex)
                {
                    threadEx = ex;
                }
            });
            t.SetApartmentState(ApartmentState.STA);
            t.Start();
            t.Join();

            if (threadEx != null)
            {
                throw new AssertFailedException($"STA Thread Hatası: {threadEx.Message}", threadEx);
            }
        }

        [TestMethod]
        public void Test_AllResolutions_NoFatalErrors_And_ValidLayoutBounds()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        // Ana konteynerler kontrolü
                        Assert.IsTrue(form.Controls.Count > 0, $"Form controls boş: {resolution}");
                        Control root = form.Controls[0];
                        Assert.IsInstanceOfType(root, typeof(TableLayoutPanel), $"Root TableLayoutPanel olmalı: {resolution}");
                        Assert.IsTrue(root.Width > 0 && root.Height > 0, $"Root boyutu geçersiz: {resolution}");
                    }
                }
            });
        }

        [TestMethod]
        public void Test_NumpadButtons_NeverOverlap_And_WithinBounds()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing();

                        // Numpad butonlarını topla
                        List<FluentButton> numpadBtns = new List<FluentButton>();
                        CollectControlsOfType(form, numpadBtns);

                        Assert.IsTrue(numpadBtns.Count >= 12, $"Numpad buton sayısı eksik: {numpadBtns.Count} ({resolution})");

                        // Numpad butonları birbirinin üstüne binmemeli
                        for (int i = 0; i < numpadBtns.Count; i++)
                        {
                            var btnA = numpadBtns[i];
                            // Buton boyutları pozitif ve kullanılabilir olmalı
                            Assert.IsTrue(btnA.Width > 15, $"Buton genişliği çok dar: {btnA.Width}px ({resolution})");
                            Assert.IsTrue(btnA.Height > 12, $"Buton yüksekliği çok basık: {btnA.Height}px ({resolution})");

                            // Buton fontu buton yüksekliğinden büyük olamaz (taşma engeli)
                            Assert.IsTrue(btnA.Font.Height <= btnA.Height,
                                $"Buton font yüksekliği ({btnA.Font.Height}px) buton yüksekliğinden ({btnA.Height}px) büyük! Taşma var ({resolution})");

                            // Çakışma kontrolü
                            for (int j = i + 1; j < numpadBtns.Count; j++)
                            {
                                var btnB = numpadBtns[j];
                                if (btnA.Parent == btnB.Parent)
                                {
                                    Rectangle rectA = btnA.Bounds;
                                    Rectangle rectB = btnB.Bounds;
                                    Assert.IsFalse(rectA.IntersectsWith(rectB),
                                        $"Numpad butonları çakışıyor! '{btnA.Text}' ({rectA}) ve '{btnB.Text}' ({rectB}) ({resolution})");
                                }
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_SchoolAndBoardLabels_DoNotOverlap()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        Label? lblSchool = FindControlByTextPrefix(form, "BİLİNMEYEN OKUL") ?? FindControlByTagOrName(form, "lblSchool");
                        Label? lblBoard = FindControlByTextPrefix(form, "İSİMSİZ TAHTA") ?? FindControlByTagOrName(form, "lblBoard");

                        if (lblSchool != null && lblBoard != null && lblSchool.Parent == lblBoard.Parent)
                        {
                            Assert.IsFalse(lblSchool.Bounds.IntersectsWith(lblBoard.Bounds),
                                $"Okul ve Tahta etiketleri üst üste biniyor! ({resolution})");
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_AnnouncementCards_AreProperlySized_And_WrapText()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        FlowLayoutPanel? pnlAnnouncements = FindControlOfType<FlowLayoutPanel>(form);
                        Assert.IsNotNull(pnlAnnouncements, $"pnlAnnouncementsList bulunamadı: {resolution}");

                        foreach (Control ctrl in pnlAnnouncements.Controls)
                        {
                            if (ctrl is FluentCard card)
                            {
                                Assert.IsTrue(card.Width > 50, $"Duyuru kartı aşırı dar: {card.Width}px ({resolution})");
                                Assert.IsTrue(card.Width <= resolution.Width * 0.38f,
                                    $"Duyuru kartı kolon sınırını aşıyor: Card Width: {card.Width} ({resolution})");
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_DynamicFontSizes_StayWithinLegibleBounds()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        List<Label> labels = new List<Label>();
                        CollectControlsOfType(form, labels);

                        foreach (var lbl in labels)
                        {
                            Assert.IsTrue(lbl.Font.Size > 5f, $"Etiket fontu aşırı küçük: {lbl.Font.Size}pt '{lbl.Text}' ({resolution})");
                            Assert.IsTrue(lbl.Font.Size < 50f, $"Etiket fontu aşırı büyük: {lbl.Font.Size}pt '{lbl.Text}' ({resolution})");
                            Assert.IsTrue(lbl.Font.Height > 0, $"Etiket font yüksekliği 0 veya negatif: {lbl.Font.Height} ({resolution})");
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_LiveResize_StressCycle()
        {
            RunInSta(() =>
            {
                using (var form = new SecureRenderer(isDesignOrTestMode: true))
                {
                    // 10 kez hızlıca boyut değiştirerek layout stres testi
                    for (int cycle = 0; cycle < 10; cycle++)
                    {
                        var res = TestResolutions[cycle % TestResolutions.Length];
                        form.Size = res;
                        form.ApplyDynamicSizing();

                        Assert.IsTrue(form.ClientSize.Width > 0);
                        Assert.IsTrue(form.ClientSize.Height > 0);
                    }
                }
            });
        }

        [TestMethod]
        public void Test_FluentButton_DrawingPath_NeverThrows_EvenAtSmallSizes()
        {
            RunInSta(() =>
            {
                // Çok küçük veya sıradışı buton boyutlarında dahi GDI+ patlamamalı
                Size[] extremeSizes = new[]
                {
                    new Size(5, 5),
                    new Size(20, 10),
                    new Size(100, 30),
                    new Size(400, 100),
                    new Size(1, 1),
                    new Size(0, 0)
                };

                foreach (var sz in extremeSizes)
                {
                    var btn = new FluentButton(8) { Size = sz, Text = "Test" };
                    if (sz.Width > 0 && sz.Height > 0)
                    {
                        using (var bmp = new Bitmap(sz.Width, sz.Height))
                        using (var g = Graphics.FromImage(bmp))
                        {
                            var pe = new PaintEventArgs(g, new Rectangle(Point.Empty, sz));
                            btn.GetType().GetMethod("OnPaint", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)
                               ?.Invoke(btn, new object[] { pe });
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_QrArea_Components_NeverOverlap()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        PictureBox? pbQr = FindControlOfType<PictureBox>(form);
                        Assert.IsNotNull(pbQr, $"Karekod alanı bulunamadı ({resolution})");

                        Control? qrParent = pbQr.Parent;
                        Assert.IsNotNull(qrParent, $"QR Parent bulunamadı ({resolution})");

                        // Kardeş kontrollerin çakışma kontrolü
                        for (int i = 0; i < qrParent.Controls.Count; i++)
                        {
                            var cA = qrParent.Controls[i];
                            for (int j = i + 1; j < qrParent.Controls.Count; j++)
                            {
                                var cB = qrParent.Controls[j];
                                Assert.IsFalse(cA.Bounds.IntersectsWith(cB.Bounds),
                                    $"QR alanında çakışma: '{cA.GetType().Name}' ve '{cB.GetType().Name}' ({resolution})");
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_PinArea_Components_NeverOverlap()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        Label? lblPinDisplay = FindControlByTextPrefix(form, "○") ?? FindControlByTextPrefix(form, "●");
                        Assert.IsNotNull(lblPinDisplay, $"lblPinDisplay bulunamadı ({resolution})");

                        Control? pinParent = lblPinDisplay.Parent;
                        Assert.IsNotNull(pinParent, $"PIN Parent bulunamadı ({resolution})");

                        for (int i = 0; i < pinParent.Controls.Count; i++)
                        {
                            var cA = pinParent.Controls[i];
                            for (int j = i + 1; j < pinParent.Controls.Count; j++)
                            {
                                var cB = pinParent.Controls[j];
                                Assert.IsFalse(cA.Bounds.IntersectsWith(cB.Bounds),
                                    $"PIN alanında çakışma: '{cA.GetType().Name}' ve '{cB.GetType().Name}' ({resolution})");
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_ExtremeTextLengths_DoNotBreakLayout()
        {
            RunInSta(() =>
            {
                foreach (var resolution in TestResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = resolution;
                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        Label? lblSchool = FindControlByTextPrefix(form, "BİLİNMEYEN OKUL");
                        if (lblSchool != null)
                        {
                            lblSchool.Text = "T.C. MİLLİ EĞİTİM BAKANLIĞI ANKARA ÇANKAYA ATATÜRK ANADOLU LİSESİ VE FEN SOSYAL BİLİMLER PROJE OKULU";
                        }

                        Label? lblBoard = FindControlByTextPrefix(form, "İSİMSİZ TAHTA");
                        if (lblBoard != null)
                        {
                            lblBoard.Text = "BİLİŞİM TEKNOLOJİLERİ VE YAZILIM LABORATUVARI - 10/B SINIFI ETKİLEŞİMLİ TAHTASI";
                        }

                        form.ApplyDynamicSizing(resolution.Width, resolution.Height);

                        if (lblSchool != null && lblBoard != null && lblSchool.Parent == lblBoard.Parent)
                        {
                            Assert.IsFalse(lblSchool.Bounds.IntersectsWith(lblBoard.Bounds),
                                $"Aşırı uzun okul/tahta adlarında çakışma oluştu! ({resolution})");
                        }
                    }
                }
            });
        }

        #region Helper Metotlar

        private static void CollectControlsOfType<T>(Control parent, List<T> result) where T : Control
        {
            foreach (Control c in parent.Controls)
            {
                if (c is T match) result.Add(match);
                if (c.HasChildren) CollectControlsOfType(c, result);
            }
        }

        private static T? FindControlOfType<T>(Control parent) where T : Control
        {
            foreach (Control c in parent.Controls)
            {
                if (c is T match) return match;
                if (c.HasChildren)
                {
                    var childMatch = FindControlOfType<T>(c);
                    if (childMatch != null) return childMatch;
                }
            }
            return null;
        }

        private static Label? FindControlByTextPrefix(Control parent, string prefix)
        {
            foreach (Control c in parent.Controls)
            {
                if (c is Label lbl && lbl.Text.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return lbl;
                if (c.HasChildren)
                {
                    var childMatch = FindControlByTextPrefix(c, prefix);
                    if (childMatch != null) return childMatch;
                }
            }
            return null;
        }

        private static Label? FindControlByTagOrName(Control parent, string name)
        {
            foreach (Control c in parent.Controls)
            {
                if (c is Label lbl && lbl.Name == name) return lbl;
                if (c.HasChildren)
                {
                    var childMatch = FindControlByTagOrName(c, name);
                    if (childMatch != null) return childMatch;
                }
            }
            return null;
        }

        #endregion
    }
}
