using System;
using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    public class SchoolUsageParameters
    {
        public int BoardCount { get; set; } = 40;
        public int TeacherCount { get; set; } = 50;
        public int PrincipalCount { get; set; } = 1;
        public int DaysPerMonth { get; set; } = 22;
        public int ClassesPerDay { get; set; } = 8;
        public int HeartbeatIntervalMinutes { get; set; } = 3;
        public int WatchdogPollIntervalMinutes { get; set; } = 5;
        public int HoursActivePerDay { get; set; } = 8;
        public int MediaPackagesPerMonth { get; set; } = 5;
        public double AverageMediaPackageSizeMB { get; set; } = 1.5;
    }

    public class DatabaseUsageMetrics
    {
        public long BoardStartupRequests { get; set; }
        public long BoardHeartbeatRequests { get; set; }
        public long BoardWatchdogRequests { get; set; }
        public long TeacherAppOpenRequests { get; set; }
        public long LockUnlockRequests { get; set; }
        public long SupportTicketRequests { get; set; }
        public long PrincipalWebRequests { get; set; }
        public long TotalRestRequests { get; set; }

        public int RealtimePeakConnections { get; set; }
        public long RealtimeLockUnlockMessages { get; set; }
        public long RealtimeHeartbeatMessages { get; set; }
        public long TotalRealtimeMessages { get; set; }

        public double MediaEgressMB { get; set; }
        public double RestJsonEgressMB { get; set; }
        public double RealtimeEgressMB { get; set; }
        public double TotalEgressGB { get; set; }
        public double EstimatedDatabaseSizeMB { get; set; }
    }

    public static class DatabaseUsageCalculator
    {
        public static DatabaseUsageMetrics CalculateMonthlyUsage(SchoolUsageParameters p)
        {
            var m = new DatabaseUsageMetrics();

            // 1. REST API İSTEKLERİ
            // Tahtalar sabah açılışta 1 kez sürüm & ping bildirir
            m.BoardStartupRequests = (long)p.BoardCount * p.DaysPerMonth;

            // Heartbeat: 8 saat = 480 dk / 3 dk = 160 ping/gün/tahta
            int pingsPerDayPerBoard = (p.HoursActivePerDay * 60) / p.HeartbeatIntervalMinutes;
            m.BoardHeartbeatRequests = (long)p.BoardCount * pingsPerDayPerBoard * p.DaysPerMonth;

            // Watchdog: 480 dk / 5 dk = 96 kontrol/gün/tahta
            int watchdogPerDayPerBoard = (p.HoursActivePerDay * 60) / p.WatchdogPollIntervalMinutes;
            m.BoardWatchdogRequests = (long)p.BoardCount * watchdogPerDayPerBoard * p.DaysPerMonth;

            // Öğretmen Mobil Açılışları: Günde ortalama 5 kez açılış (profile + school + boards = 3 istek)
            m.TeacherAppOpenRequests = (long)p.TeacherCount * 5 * 3 * p.DaysPerMonth;

            // Kilit Açma / Kapama İstekleri: 40 derslik * 8 ders * 2 işlem (aç+kapa) = 640/gün
            long dailyLockOps = (long)p.BoardCount * p.ClassesPerDay * 2;
            m.LockUnlockRequests = dailyLockOps * p.DaysPerMonth;

            // Arıza ve destek bildirimleri: Ayda ~50 istek
            m.SupportTicketRequests = 50;

            // Müdür Web Paneli: Günde 5 oturum * 10 sorgu + 5 afiş yükleme
            m.PrincipalWebRequests = (long)p.PrincipalCount * ((5 * 10 * p.DaysPerMonth) + 50);

            m.TotalRestRequests = m.BoardStartupRequests + m.BoardHeartbeatRequests +
                                  m.BoardWatchdogRequests + m.TeacherAppOpenRequests +
                                  m.LockUnlockRequests + m.SupportTicketRequests +
                                  m.PrincipalWebRequests;

            // 2. REALTIME WEBSOCKET BAĞLANTILARI & MESAJLARI
            // Peak Bağlantı: 40 tahta + eşzamanlı aktif ~15 öğretmen + 1 müdür
            m.RealtimePeakConnections = p.BoardCount + 15 + p.PrincipalCount;

            // Kilit Açma/Kapama Mesajları:
            // Yaptığımız school_id filtrelemesi sayesinde her kilit olayı:
            // 1 hedef tahta + o an okulda açık ~10 öğretmen telefonu + 1 müdür paneli = ~12 alıcı
            int listenersPerLockEvent = 1 + 10 + 1;
            m.RealtimeLockUnlockMessages = dailyLockOps * listenersPerLockEvent * p.DaysPerMonth;

            // Heartbeat Realtime Mesajları (Sadece müdür web paneli açıksa dinler):
            m.RealtimeHeartbeatMessages = (long)p.BoardCount * pingsPerDayPerBoard * p.DaysPerMonth * 1;

            m.TotalRealtimeMessages = m.RealtimeLockUnlockMessages + m.RealtimeHeartbeatMessages;

            // 3. EGRESS & DEPOLAMA (Bant Genişliği)
            // 5 afiş * 1.5 MB * 40 tahta indirmesi
            m.MediaEgressMB = p.MediaPackagesPerMonth * p.AverageMediaPackageSizeMB * p.BoardCount;

            // REST JSON Egress: Ortalama 1 KB/istek
            m.RestJsonEgressMB = (m.TotalRestRequests * 1.0) / 1024.0;

            // Realtime WebSocket Egress: Ortalama 0.5 KB/mesaj
            m.RealtimeEgressMB = (m.TotalRealtimeMessages * 0.5) / 1024.0;

            m.TotalEgressGB = (m.MediaEgressMB + m.RestJsonEgressMB + m.RealtimeEgressMB) / 1024.0;

            // Veritabanı tablo boyutu (Okul, tahtalar, profiller, biletler, WAL)
            m.EstimatedDatabaseSizeMB = 15.0;

            return m;
        }

        public static (int maxSchoolsByConnections, int maxSchoolsByMessages, int maxSchoolsByEgress, int overallCapacitySchools)
            CalculateProPlanCapacity(DatabaseUsageMetrics schoolUsage)
        {
            // Supabase Pro Plan Dahil Kotalar ($25 / ay):
            const int proConnectionsQuota = 500;
            const long proMessagesQuota = 5000000;
            const double proEgressGBQuota = 250.0;

            int capByConn = proConnectionsQuota / Math.Max(1, schoolUsage.RealtimePeakConnections);
            int capByMsg = (int)(proMessagesQuota / Math.Max(1, schoolUsage.TotalRealtimeMessages));
            int capByEgress = (int)(proEgressGBQuota / Math.Max(0.1, schoolUsage.TotalEgressGB));

            // En kısıtlayıcı darboğaza göre genel kapasite
            int overall = Math.Min(capByConn, Math.Min(capByMsg, capByEgress));

            return (capByConn, capByMsg, capByEgress, overall);
        }
    }

    [TestClass]
    public class DatabaseUsageSimulationTests
    {
        public TestContext TestContext { get; set; } = null!;

        [TestMethod]
        public void Test_SimulateOneMonth_RESTRequests_WithinBudget()
        {
            var p = new SchoolUsageParameters();
            var m = DatabaseUsageCalculator.CalculateMonthlyUsage(p);

            Assert.IsTrue(m.TotalRestRequests > 200000, $"Aylık REST isteği çok düşük hesaplandı: {m.TotalRestRequests}");
            Assert.IsTrue(m.TotalRestRequests < 350000, $"Aylık REST isteği aşırı yüksek: {m.TotalRestRequests}");

            // Günlük ortalama saniyedeki istek sayısı (RPS):
            // 22 gün * 8 saat = 176 saat = 633,600 saniye
            double rps = (double)m.TotalRestRequests / (p.DaysPerMonth * p.HoursActivePerDay * 3600);
            Assert.IsTrue(rps < 0.8, $"Saniyedeki istek yükü Supabase için çok yüksek: {rps:F2} RPS");
        }

        [TestMethod]
        public void Test_SimulateOneMonth_RealtimeMessages_And_PeakConcurrency()
        {
            var p = new SchoolUsageParameters();
            var m = DatabaseUsageCalculator.CalculateMonthlyUsage(p);

            // Supabase Free Plan limitleri: 200 connection, 2M message
            Assert.IsTrue(m.RealtimePeakConnections <= 200, $"Free connection kotası aşıldı: {m.RealtimePeakConnections}");
            Assert.IsTrue(m.TotalRealtimeMessages <= 2000000, $"Free mesaj kotası aşıldı: {m.TotalRealtimeMessages}");

            // Supabase Pro Plan limitleri: 500 connection, 5M message
            Assert.IsTrue(m.RealtimePeakConnections <= 500);
            Assert.IsTrue(m.TotalRealtimeMessages <= 5000000);
        }

        [TestMethod]
        public void Test_SimulateOneMonth_Egress_And_Storage_Consumption()
        {
            var p = new SchoolUsageParameters();
            var m = DatabaseUsageCalculator.CalculateMonthlyUsage(p);

            // Free Plan Egress kotası 5 GB'tır. 1 okul 1 GB'ın altında kalmalıdır.
            Assert.IsTrue(m.TotalEgressGB < 1.0, $"Aylık Egress 1 GB altında olmalıdır: {m.TotalEgressGB:F2} GB");
            Assert.IsTrue(m.EstimatedDatabaseSizeMB < 50.0, "Veritabanı boyutu 50 MB altında olmalıdır");
        }

        [TestMethod]
        public void Test_CalculateMultiSchoolCapacity_OnProPlan()
        {
            var p = new SchoolUsageParameters();
            var m = DatabaseUsageCalculator.CalculateMonthlyUsage(p);
            var (capByConn, capByMsg, capByEgress, overall) = DatabaseUsageCalculator.CalculateProPlanCapacity(m);

            // Tek bir $25 Pro planda en az 8-10 okul barınabilmelidir
            Assert.IsTrue(overall >= 8, $"Pro plandaki okul kapasitesi yetersiz: {overall}");
            Assert.IsTrue(capByMsg >= 15, $"Mesaj kapasitesi en az 15 okul olmalı: {capByMsg}");
            Assert.IsTrue(capByEgress >= 100, $"Egress kapasitesi en az 100 okul olmalı: {capByEgress}");
        }

        [TestMethod]
        public void Test_PrintFullAnalyticalUsageAndCostReport()
        {
            var p = new SchoolUsageParameters();
            var m = DatabaseUsageCalculator.CalculateMonthlyUsage(p);
            var (capByConn, capByMsg, capByEgress, overall) = DatabaseUsageCalculator.CalculateProPlanCapacity(m);

            double costPerSchoolUsd = 25.0 / overall;
            double usdTryRate = 36.0; // Tahmini kur
            double costPerSchoolTry = costPerSchoolUsd * usdTryRate;
            double costPerBoardTry = costPerSchoolTry / p.BoardCount;

            var sb = new StringBuilder();
            sb.AppendLine("================================================================================");
            sb.AppendLine("SINIF360 SUPABASE VERİTABANI VE ALTYAPI MALİYET ANALİZ RAPORU");
            sb.AppendLine("================================================================================");
            sb.AppendLine($"Okul Parametreleri: {p.BoardCount} Tahta | {p.TeacherCount} Öğretmen | {p.PrincipalCount} Müdür | {p.DaysPerMonth} Gün | Günde {p.ClassesPerDay} Ders");
            sb.AppendLine("--------------------------------------------------------------------------------");
            sb.AppendLine("1. AYLIK REST API KULLANIMI:");
            sb.AppendLine($"   - Tahta Başlangıç İstekleri:        {m.BoardStartupRequests:N0} istek");
            sb.AppendLine($"   - Tahta Heartbeat (3 dk periyot):    {m.BoardHeartbeatRequests:N0} istek");
            sb.AppendLine($"   - Tahta Watchdog (5 dk kontrol):     {m.BoardWatchdogRequests:N0} istek");
            sb.AppendLine($"   - Öğretmen Mobil Giriş ve Sorgu:     {m.TeacherAppOpenRequests:N0} istek");
            sb.AppendLine($"   - Kilit Açma / Kapama İstekleri:     {m.LockUnlockRequests:N0} istek");
            sb.AppendLine($"   - Destek ve Arıza Bildirimleri:      {m.SupportTicketRequests:N0} istek");
            sb.AppendLine($"   - Müdür Web Paneli İzleme:           {m.PrincipalWebRequests:N0} istek");
            sb.AppendLine($"   >> TOPLAM AYLIK REST İSTEĞİ:        {m.TotalRestRequests:N0} İSTEK / AY (~{m.TotalRestRequests / 1000}K)");
            sb.AppendLine("--------------------------------------------------------------------------------");
            sb.AppendLine("2. REALTIME WEBSOCKET TRAFİĞİ:");
            sb.AppendLine($"   - Anlık Eşzamanlı Bağlantı (Peak):   {m.RealtimePeakConnections} Bağlantı (Free Kota: 200 | Pro Kota: 500)");
            sb.AppendLine($"   - Kilit Açma/Kapama Mesajları:       {m.RealtimeLockUnlockMessages:N0} mesaj");
            sb.AppendLine($"   - Heartbeat Realtime Mesajları:      {m.RealtimeHeartbeatMessages:N0} mesaj");
            sb.AppendLine($"   >> TOPLAM REALTIME MESAJI:           {m.TotalRealtimeMessages:N0} MESAJ / AY (~{m.TotalRealtimeMessages / 1000}K)");
            sb.AppendLine("--------------------------------------------------------------------------------");
            sb.AppendLine("3. BANT GENİŞLİĞİ VE DEPOLAMA:");
            sb.AppendLine($"   - Afiş İndirme Transferi (5 Paket):  {m.MediaEgressMB:F1} MB");
            sb.AppendLine($"   - REST JSON Veri Transferi:          {m.RestJsonEgressMB:F1} MB");
            sb.AppendLine($"   - Realtime WebSocket Transferi:      {m.RealtimeEgressMB:F1} MB");
            sb.AppendLine($"   >> TOPLAM AYLIK EGRESS:              {m.TotalEgressGB:F3} GB / AY (Free Kota: 5 GB | Pro Kota: 250 GB)");
            sb.AppendLine($"   >> TAHMİNİ VERİTABANI DİSK BOYUTU:   {m.EstimatedDatabaseSizeMB:F1} MB (Free: 500 MB | Pro: 8 GB)");
            sb.AppendLine("--------------------------------------------------------------------------------");
            sb.AppendLine("4. SUPABASE PRO PLAN ($25 / AY) ÇOKLU OKUL KAPASİTESİ:");
            sb.AppendLine($"   - Realtime Bağlantıya Göre Kapasite: {capByConn} Okul");
            sb.AppendLine($"   - Realtime Mesaj Kotasına Göre:      {capByMsg} Okul");
            sb.AppendLine($"   - Egress Bant Genişliğine Göre:      {capByEgress} Okul");
            sb.AppendLine($"   >> GÜVENLİ OKUL KAPASİTESİ:          {overall} OKUL (Tek bir $25 pakette)");
            sb.AppendLine("--------------------------------------------------------------------------------");
            sb.AppendLine("5. FİNANSAL MALİYET ÇIKARIMI (BİRİM MALİYET):");
            sb.AppendLine($"   - Okul Başına Aylık Altyapı Maliyeti: ${costPerSchoolUsd:F2} / Okul / Ay (~{costPerSchoolTry:F2} TL / Ay)");
            sb.AppendLine($"   - Tahta Başına Aylık Altyapı Maliyeti: ~{costPerBoardTry:F2} TL / Tahta / Ay");
            sb.AppendLine("================================================================================");

            string report = sb.ToString();
            Console.WriteLine(report);
            TestContext.WriteLine(report);

            Assert.IsTrue(report.Contains("SINIF360 SUPABASE"));
        }
    }
}
