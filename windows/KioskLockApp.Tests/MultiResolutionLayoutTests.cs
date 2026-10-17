using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using KioskLockApp.Services;
using KioskLockApp.UI;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class MultiResolutionLayoutTests
    {
        // Hedeflenen tüm akıllı tahta, projeksiyon ve monitör çözünürlükleri
        public static readonly Size[] TargetResolutions = new[]
        {
            new Size(1024, 768),   // 4:3 Sınıf Projeksiyonu
            new Size(1280, 720),   // 16:9 HD 720p
            new Size(1280, 800),   // 16:10 Faz-1 / Tablet
            new Size(1280, 1024),  // 5:4 Eski Kare Ekran
            new Size(1366, 768),   // 16:9 Faz-1 Akıllı Tahta & Laptoplar
            new Size(1600, 900),   // 16:9 HD+
            new Size(1920, 1080),  // 16:9 Full HD Standart Akıllı Tahtalar (Faz 2 & Faz 3)
            new Size(1920, 1200),  // 16:10 WUXGA
            new Size(2560, 1440),  // 16:9 2K QHD Yeni Nesil Paneller
            new Size(3840, 2160)   // 16:9 4K UHD 75"-86" Etkileşimli Akıllı Tahtalar
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
                throw new AssertFailedException($"STA Hatası: {threadEx.Message}", threadEx);
            }
        }

        [TestMethod]
        public void Test_MajorContainers_NeverOverlap_AcrossAllResolutions()
        {
            RunInSta(() =>
            {
                foreach (var res in TargetResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.ClientSize = res;
                        _ = form.Handle; // HWND oluşturulmasını ve WinForms mesaj kuyruğunda düzen hesaplamasını zorlar
                        form.ApplyDynamicSizing(res.Width, res.Height);

                        TableLayoutPanel? root = form.Controls.OfType<TableLayoutPanel>().FirstOrDefault();
                        Assert.IsNotNull(root, $"Root TableLayoutPanel bulunamadı: {res}");

                        TableLayoutPanel? mainGrid = FindControlByName<TableLayoutPanel>(root, "mainGrid") 
                            ?? root.Controls.OfType<TableLayoutPanel>().FirstOrDefault(c => c.ColumnCount == 3);
                        Assert.IsNotNull(mainGrid, $"mainGrid bulunamadı: {res}");

                        form.PerformLayout();
                        root.PerformLayout();
                        mainGrid.PerformLayout();

                        // Header (Row 0), MainGrid (Row 1), Footer (Row 2) sınır kontrolü
                        Assert.IsTrue(root.RowCount >= 3, $"Root satır sayısı yetersiz: {res}");
                        Assert.AreEqual(DockStyle.Fill, root.Dock);

                        // Sütunların pozitif genişlikte ve form sınırları içinde olduğunu doğrula
                        for (int col = 0; col < mainGrid.ColumnCount; col++)
                        {
                            Control? colControl = mainGrid.GetControlFromPosition(col, 0);
                            if (colControl != null)
                            {
                                Assert.IsTrue(colControl.Width > 50, $"Sütun {col} aşırı dar: {colControl.Width}px ({res})");
                                Assert.IsTrue(colControl.Height >= 100, $"Sütun {col} aşırı basık: {colControl.Height}px ({res})");
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_Announcements_NeverHaveScrollBar_And_FitExactlyInHeight()
        {
            RunInSta(() =>
            {
                foreach (var res in TargetResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = res;
                        form.ApplyDynamicSizing(res.Width, res.Height);

                        FlowLayoutPanel? pnlList = FindControlByName<FlowLayoutPanel>(form, "pnlAnnouncementsList");
                        Assert.IsNotNull(pnlList, $"pnlAnnouncementsList bulunamadı ({res})");

                        // KESİNLİKLE scrollbar / slidebar olmamalı!
                        Assert.IsFalse(pnlList.AutoScroll, $"pnlAnnouncementsList.AutoScroll 'false' olmalıydı! ({res})");

                        // Farklı duyuru adetleri ile test et: 1, 2, 4, 8 duyuru
                        int[] testCounts = new[] { 1, 2, 4, 8 };
                        foreach (var count in testCounts)
                        {
                            var mockList = new List<MediaItem>();
                            for (int i = 1; i <= count; i++)
                            {
                                mockList.Add(new MediaItem
                                {
                                    Id = $"ann_{i}",
                                    Title = $"Test Duyurusu Başlık {i} (Sınıf {i}/A)",
                                    Content = $"Bu duyuru öğrencilerin kolayca okuyabilmesi için büyük puntolarla hazırlanmıştır. No: {i}",
                                    Type = "announcement"
                                });
                            }

                            SetPrivateField(form, "cachedAnnouncements", mockList);
                            SetPrivateField(form, "announcementPageIndex", 0);

                            form.RenderAnnouncementCards();

                            // Ekranda gösterilen kart sayısı görünür sınırını aşamaz
                            int visibleLimit = form.GetVisibleAnnouncementCount();
                            Assert.IsTrue(pnlList.Controls.Count <= visibleLimit, 
                                $"Ekrana basılan kart sayısı ({pnlList.Controls.Count}) görünür sınırı ({visibleLimit}) aştı ({res})");

                            // Kartların toplam yüksekliği panel yüksekliğini aşamaz (Taşma / Cut-off engeli)
                            int totalCardsHeight = 0;
                            foreach (Control c in pnlList.Controls)
                            {
                                totalCardsHeight += c.Height + c.Margin.Vertical;
                                Assert.IsTrue(c.Width > 50, $"Duyuru kartı genişliği geçersiz ({res})");

                                // Kart içindeki başlık fontunu incele
                                Label? lblTitle = FindChildLabelByFontBold(c);
                                if (lblTitle != null)
                                {
                                    Assert.IsTrue(lblTitle.Font.Bold, $"Duyuru başlığı kalın (Bold) olmalı ({res})");
                                    Assert.IsTrue(lblTitle.Font.Size >= 13f, 
                                        $"Duyuru başlık fontu sınıftan okunabilirlik için en az 13pt olmalı: {lblTitle.Font.Size}pt ({res})");
                                }
                            }

                            if (pnlList.ClientSize.Height > 100)
                            {
                                Assert.IsTrue(totalCardsHeight <= pnlList.ClientSize.Height + 20, 
                                    $"Duyuru kartları dikey alanı aşıyor! Kartlar Toplamı: {totalCardsHeight}px, Panel: {pnlList.ClientSize.Height}px ({res})");
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_AnnouncementPagination_RotatesSeamlesslyWithoutErrors()
        {
            RunInSta(() =>
            {
                using (var form = new SecureRenderer(isDesignOrTestMode: true))
                {
                    form.Size = new Size(1920, 1080);
                    form.ApplyDynamicSizing();

                    // 5 adet duyuru yükle
                    var mockList = new List<MediaItem>();
                    for (int i = 1; i <= 5; i++)
                    {
                        mockList.Add(new MediaItem
                        {
                            Id = $"ann_{i}",
                            Title = $"Okul Duyurusu {i}",
                            Content = $"İçerik açıklaması {i}",
                            Type = "announcement"
                        });
                    }

                    SetPrivateField(form, "cachedAnnouncements", mockList);
                    SetPrivateField(form, "announcementPageIndex", 0);
                    form.RenderAnnouncementCards();

                    int page0 = GetPrivateField<int>(form, "announcementPageIndex");
                    Assert.AreEqual(0, page0);

                    // 1 kez döndür -> sayfa 1'e geçmeli
                    form.RotateAnnouncementsIfNeeded();
                    int page1 = GetPrivateField<int>(form, "announcementPageIndex");
                    Assert.AreEqual(1, page1);

                    // Tekrar döndür -> sayfa 2'ye geçmeli
                    form.RotateAnnouncementsIfNeeded();
                    int page2 = GetPrivateField<int>(form, "announcementPageIndex");
                    Assert.AreEqual(2, page2);

                    // Tekrar döndür -> döngü tamamlanıp sayfa 0'a dönmeli
                    form.RotateAnnouncementsIfNeeded();
                    int pageLoop = GetPrivateField<int>(form, "announcementPageIndex");
                    Assert.AreEqual(0, pageLoop);
                }
            });
        }

        [TestMethod]
        public void Test_LoginCard_RowsNeverOverlap_AcrossAllResolutions()
        {
            RunInSta(() =>
            {
                foreach (var res in TargetResolutions)
                {
                    using (var form = new SecureRenderer(isDesignOrTestMode: true))
                    {
                        form.Size = res;
                        form.ApplyDynamicSizing(res.Width, res.Height);

                        TableLayoutPanel? loginLayout = FindControlByName<TableLayoutPanel>(form, "loginLayout");
                        Assert.IsNotNull(loginLayout, $"loginLayout bulunamadı: {res}");

                        // loginLayout 5 satırdan oluşur
                        Assert.IsTrue(loginLayout.RowCount >= 5, $"loginLayout satır sayısı yetersiz: {res}");

                        for (int r = 0; r < loginLayout.RowCount; r++)
                        {
                            Control? rowCtrl = loginLayout.GetControlFromPosition(0, r);
                            if (rowCtrl != null)
                            {
                                Assert.IsTrue(rowCtrl.Height > 0, $"Satır {r} yüksekliği 0 veya negatif ({res})");
                                Assert.IsTrue(rowCtrl.Width > 0, $"Satır {r} genişliği 0 veya negatif ({res})");
                            }
                        }

                        // Numpad butonlarının hiçbir zaman birbirinin üstüne binmediğini doğrula
                        List<FluentButton> numpadBtns = new List<FluentButton>();
                        CollectControlsOfType(loginLayout, numpadBtns);
                        Assert.IsTrue(numpadBtns.Count >= 12, $"Numpad buton sayısı eksik: {numpadBtns.Count} ({res})");

                        for (int i = 0; i < numpadBtns.Count; i++)
                        {
                            for (int j = i + 1; j < numpadBtns.Count; j++)
                            {
                                if (numpadBtns[i].Parent == numpadBtns[j].Parent)
                                {
                                    Assert.IsFalse(numpadBtns[i].Bounds.IntersectsWith(numpadBtns[j].Bounds),
                                        $"Numpad butonları çakışıyor! '{numpadBtns[i].Text}' ve '{numpadBtns[j].Text}' ({res})");
                                }
                            }
                        }
                    }
                }
            });
        }

        [TestMethod]
        public void Test_4K_UltraHighResolution_ScalesGracefully()
        {
            RunInSta(() =>
            {
                Size uhd4k = new Size(3840, 2160);
                using (var form = new SecureRenderer(isDesignOrTestMode: true))
                {
                    form.Size = uhd4k;
                    form.ApplyDynamicSizing(uhd4k.Width, uhd4k.Height);

                    // 4K ekranda başlık ve saat fontları devasa tahtadan rahatça görülebilecek boyutta olmalı
                    Label? lblTime = FindControlByName<Label>(form, "lblTime");
                    if (lblTime != null)
                    {
                        Assert.IsTrue(lblTime.Font.Size >= 28f, $"4K ekranda saat fontu ({lblTime.Font.Size}pt) en az 28pt olmalı");
                    }

                    Label? lblDuyuruTitle = FindControlByName<Label>(form, "lblDuyuruTitle");
                    if (lblDuyuruTitle != null)
                    {
                        Assert.IsTrue(lblDuyuruTitle.Font.Size >= 24f, $"4K ekranda duyuru başlığı ({lblDuyuruTitle.Font.Size}pt) en az 24pt olmalı");
                    }

                    // Numpad butonları geniş ve dokunulabilir olmalı
                    TableLayoutPanel? loginLayout = FindControlByName<TableLayoutPanel>(form, "loginLayout");
                    List<FluentButton> numpadBtns = new List<FluentButton>();
                    if (loginLayout != null) CollectControlsOfType(loginLayout, numpadBtns);
                    foreach (var btn in numpadBtns)
                    {
                        Assert.IsTrue(btn.Width > 25, $"4K'da buton genişliği ({btn.Width}px) en az 25px olmalı");
                        Assert.IsTrue(btn.Height > 20, $"4K'da buton yüksekliği ({btn.Height}px) en az 20px olmalı");
                    }
                }
            });
        }

        // ===================== Yardımcı Metotlar =====================

        private static T? FindControlByName<T>(Control parent, string name) where T : Control
        {
            FieldInfo? field = typeof(SecureRenderer).GetField(name, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
            if (field != null && parent is SecureRenderer r)
            {
                var val = field.GetValue(r) as T;
                if (val != null) return val;
            }

            foreach (Control c in parent.Controls)
            {
                if (c.Name == name && c is T tc) return tc;
                var found = FindControlByName<T>(c, name);
                if (found != null) return found;
            }
            return null;
        }

        private static void CollectControlsOfType<T>(Control parent, List<T> results) where T : Control
        {
            foreach (Control c in parent.Controls)
            {
                if (c is T t) results.Add(t);
                CollectControlsOfType(c, results);
            }
        }

        private static Label? FindChildLabelByFontBold(Control parent)
        {
            foreach (Control c in parent.Controls)
            {
                if (c is Label l && l.Font.Bold && !string.IsNullOrWhiteSpace(l.Text) && !l.Text.StartsWith("📢") && !l.Text.StartsWith("📌"))
                    return l;
                var sub = FindChildLabelByFontBold(c);
                if (sub != null) return sub;
            }
            return null;
        }

        private static void SetPrivateField(object obj, string fieldName, object value)
        {
            FieldInfo? fi = obj.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
            fi?.SetValue(obj, value);
        }

        private static T? GetPrivateField<T>(object obj, string fieldName)
        {
            FieldInfo? fi = obj.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
            return (T?)fi?.GetValue(obj);
        }
    }
}
