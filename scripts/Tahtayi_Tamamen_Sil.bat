@echo off
chcp 65001 >nul
title Sınıf360 - Tamamen Kaldırma ve Temizleme Aracı

:: Yönetici Yetkisi Kontrolü ve Otomatik Yükseltme
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Yönetici yetkileri alınıyor...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ======================================================
echo   SINIF360 - TAMAMEN KALDIRMA VE TEMİZLEME ARACI
echo ======================================================
echo.
echo Bu işlem:
echo  1. Çalışan tüm Sınıf360 süreçlerini sonlandıracak.
echo  2. Başlangıç (Autostart) kayıtlarını temizleyecek.
echo  3. Registry (Eşleştirme ve Lisans) verilerini silecek.
echo  4. C:\ProgramData\AkilliTahtaKilitSistemi klasörünü tamamen silecek.
echo.
set /p ONAY="Devam etmek istiyor musunuz? (E/H): "
if /i not "%ONAY%"=="E" (
    echo İşlem iptal edildi.
    timeout /t 2 >nul
    exit /b
)

echo.
echo [1/5] Süreçler kapatılıyor...
taskkill /f /im WatchdogService.exe >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /f /im KioskLockApp.exe >nul 2>&1
taskkill /f /im TahtaUpdater.exe >nul 2>&1
taskkill /f /im TahtaRepair.exe >nul 2>&1
taskkill /f /im WatchdogService.exe >nul 2>&1
taskkill /f /im KioskLockApp.exe >nul 2>&1

echo [2/5] Başlangıç kayıtları (Run Keys) siliniyor...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaKilitSistemi" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaWatchdog" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaKilitSistemi" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaWatchdog" /f >nul 2>&1

echo [3/5] Kayıt Defteri (Registry) ayarları siliniyor...
reg delete "HKCU\Software\SmartBoardLock" /f >nul 2>&1
reg delete "HKLM\Software\SmartBoardLock" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A3B982A3-CD89-4361-8FB7-89DA4109EF89}_is1" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A3B982A3-CD89-4361-8FB7-89DA4109EF89}_is1" /f >nul 2>&1

echo [4/5] Sistem kısıtlamaları kaldırılıyor...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1

echo [5/5] Program dosyaları siliniyor...
if exist "C:\ProgramData\AkilliTahtaKilitSistemi" (
    rmdir /s /q "C:\ProgramData\AkilliTahtaKilitSistemi" >nul 2>&1
)

echo.
echo ======================================================
echo   [BAŞARILI] Sınıf360 bilgisayardan tamamen kaldırıldı!
echo ======================================================
echo.
pause
exit
