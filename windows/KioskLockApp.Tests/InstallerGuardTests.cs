using System;
using KioskLockApp.Services;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class InstallerGuardTests
    {
        [TestMethod]
        public void IsTargetProcess_MatchesMsiexecAndSetupsAndUninstalls()
        {
            // msiexec
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("msiexec.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("msiexec"));

            // *setup*
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("setup.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("vcredist_setup_x64.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("SetupHelper.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("game_setup.exe"));

            // *install*
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("installer.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("chrome_installer.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("AppInstallService.exe"));

            // unins* or *uninstall*
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("unins000.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("uninstall.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("app_uninstaller.exe"));

            // Turkish installers & uninstallers (*kurulum*, *kur*, *kaldir*)
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("kurulum.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("oyun_kurulum.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("e_okul_kurulum.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("program_kur.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("kaldir.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("uygulama_kaldir.exe"));

            // Package managers (winget, choco)
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("winget.exe"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("winget"));
            Assert.IsTrue(InstallerGuardService.IsTargetProcess("choco.exe"));
        }

        [TestMethod]
        public void IsTargetProcess_WhitelistsWindowsUpdateProcesses()
        {
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("TrustedInstaller.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("TiWorker.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("wuauclt.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("UsoClient.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("MoUsoCoreWorker.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("WaaSMedicAgent.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("SIHClient.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("dism.exe"));
        }

        [TestMethod]
        public void IsTargetProcess_WhitelistsWindowsDefenderProcesses()
        {
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("MpSigStub.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("MsMpEng.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("NisSrv.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("MpCmdRun.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("smartscreen.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("SecurityHealthService.exe"));
        }

        [TestMethod]
        public void IsTargetProcess_WhitelistsSinif360EcosystemApps()
        {
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("KioskLockApp.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("WatchdogService.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("TahtaRepair.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("TahtaUpdater.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("Sinif360Kaldir.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("Sinif360_Kaldir.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("Sinif360Kapat.exe"));
        }

        [TestMethod]
        public void IsTargetProcess_WhitelistsDefenderPlatformDirectoryPath()
        {
            string defenderUpdatePath = @"C:\ProgramData\Microsoft\Windows Defender\Platform\4.18.23050.5-0\MpSigStub.exe";
            Assert.IsTrue(InstallerGuardService.IsWhitelisted("mpsigstub.exe", defenderUpdatePath));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("mpsigstub.exe", defenderUpdatePath));
        }

        [TestMethod]
        public void IsTargetProcess_IgnoresNormalApplications()
        {
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("notepad.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("calc.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("chrome.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("explorer.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("WINWORD.EXE"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("EXCEL.EXE"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("powershell.exe"));
            Assert.IsFalse(InstallerGuardService.IsTargetProcess("cmd.exe"));
        }
    }
}
