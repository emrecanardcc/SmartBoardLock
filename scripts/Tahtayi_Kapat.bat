@echo off
chcp 65001 >nul
title Sınıf360 - Kapatma Aracı

:: 1. Yönetici Yetkisi Kontrolü ve Düzgün Yükseltme
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Yönetici yetkileri alınıyor...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c', '\"\"\"%~f0\"\"\"' -Verb RunAs"
    exit /b
)

echo ======================================================
echo   SINIF360 - KİLİT VE BEKÇİ SÜREÇLERİNİ DURDURMA
echo ======================================================
echo.

:: Eğer derlenmiş C# kapatma programı mevcutsa doğrudan onu çağır
if exist "%~dp0Sinif360_Kapat.exe" (
    echo C# Kapatma Programı çalıştırılıyor...
    "%~dp0Sinif360_Kapat.exe" --now
    goto :after_kill
)
if exist "%~dp0..\windows\Publish_Sinif360Kapat\Sinif360_Kapat.exe" (
    echo C# Kapatma Programı çalıştırılıyor...
    "%~dp0..\windows\Publish_Sinif360Kapat\Sinif360_Kapat.exe" --now
    goto :after_kill
)

:: Alternatif / Doğrudan Toplu Taskkill (Tüm süreçler aynı anda tek komutta)
echo Süreçler sonlandırılıyor...
taskkill /f /t /im WatchdogService.exe /im KioskLockApp.exe /im TahtaUpdater.exe /im TahtaRepair.exe >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /f /t /im WatchdogService.exe /im KioskLockApp.exe /im TahtaUpdater.exe /im TahtaRepair.exe >nul 2>&1

:after_kill
:: Sistem güvenlik kısıtlamalarını kaldır
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRun /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRun /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /f >nul 2>&1

echo.
echo [BAŞARILI] Sınıf360 kilit ve bekçi servisleri tamamen durduruldu.
echo.
timeout /t 3
exit
