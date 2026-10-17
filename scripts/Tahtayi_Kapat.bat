@echo off
chcp 65001 >nul
title Sınıf360 - Kapatma Aracı

:: Yönetici Yetkisi Kontrolü ve Otomatik Yükseltme
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Yönetici yetkileri alınıyor...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ======================================================
echo   SINIF360 - TÜM SÜREÇLERİ DURDURMA ARACI
echo ======================================================
echo.

echo 1. Bekçi Servisi (WatchdogService) kapatılıyor...
taskkill /f /im WatchdogService.exe >nul 2>&1
timeout /t 1 /nobreak >nul

echo 2. Kilit Uygulaması (KioskLockApp) kapatılıyor...
taskkill /f /im KioskLockApp.exe >nul 2>&1

echo 3. Güncelleyici ve Onarım Araçları kapatılıyor...
taskkill /f /im TahtaUpdater.exe >nul 2>&1
taskkill /f /im TahtaRepair.exe >nul 2>&1

:: İkinci kontrol (Watchdog yeniden tetiklememiş olsun)
taskkill /f /im WatchdogService.exe >nul 2>&1
taskkill /f /im KioskLockApp.exe >nul 2>&1

:: Görev Yöneticisi kısıtlamalarını kaldır
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1

echo.
echo [BAŞARILI] Sınıf360 kilit ve bekçi servisleri tamamen durduruldu.
echo.
timeout /t 3
exit
