@echo off
chcp 65001 >nul
title Sınıf360 - Geliştirici ve Test Kontrol Merkezi

:: Yönetici Yetkisi Kontrolü ve Otomatik Yükseltme
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Yönetici yetkileri alınıyor...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo =====================================================================
echo           SINIF360 - TEST VE GELİŞTİRİCİ KONTROL PANELİ
echo =====================================================================
echo.
echo   [1] Sadece Programı Kapat (KioskLockApp ^& Watchdog'u Durdur)
echo   [2] Programı Başlat (Watchdog ve Kilit Uygulamasını Çalıştır)
echo   [3] Eşleşmeyi Sıfırla (Dosyalar kalır, tahta sıfırlanıp yeni kod üretir)
echo   [4] Programı Tamamen Kaldır ve Temizle (Dosyalar, Kayıtlar, Her Şey)
echo   [5] Canlı Durumu ve Süreçleri Kontrol Et
echo.
echo   [0] Çıkış
echo =====================================================================
set /p SECIM="Lütfen bir işlem seçin (0-5): "

if "%SECIM%"=="1" goto KAPAT
if "%SECIM%"=="2" goto BASLAT
if "%SECIM%"=="3" goto SIFIRLA
if "%SECIM%"=="4" goto TAMAMEN_SIL
if "%SECIM%"=="5" goto DURUM
if "%SECIM%"=="0" exit /b
goto MENU

:KAPAT
cls
echo [KAPATMA] Tüm Sınıf360 servisleri durduruluyor...
taskkill /f /im WatchdogService.exe >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /f /im KioskLockApp.exe >nul 2>&1
taskkill /f /im TahtaUpdater.exe >nul 2>&1
taskkill /f /im TahtaRepair.exe >nul 2>&1
taskkill /f /im WatchdogService.exe >nul 2>&1
taskkill /f /im KioskLockApp.exe >nul 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1

echo.
echo [BAŞARILI] Tüm süreçler kapatıldı ve Görev Yöneticisi erişimi açıldı.
echo.
pause
goto MENU

:BASLAT
cls
echo [BAŞLATMA] Uygulama başlatılıyor...
if exist "C:\ProgramData\AkilliTahtaKilitSistemi\WatchdogService.exe" (
    start "" "C:\ProgramData\AkilliTahtaKilitSistemi\WatchdogService.exe"
    start "" "C:\ProgramData\AkilliTahtaKilitSistemi\KioskLockApp.exe"
    echo [BAŞARILI] WatchdogService ve KioskLockApp başlatıldı.
) else if exist "C:\Projeler\AkilliTahtaSistemi\dist\v2.1.1_publish\KioskLockApp.exe" (
    start "" "C:\Projeler\AkilliTahtaSistemi\dist\v2.1.1_publish\WatchdogService.exe"
    start "" "C:\Projeler\AkilliTahtaSistemi\dist\v2.1.1_publish\KioskLockApp.exe"
    echo [BAŞARILI] dist klasöründen başlatıldı.
) else (
    echo [HATA] KioskLockApp.exe bulunamadı! Lütfen önce kurulum yapın.
)
echo.
pause
goto MENU

:SIFIRLA
cls
echo [SIFIRLAMA] Eşleştirme ve tahta ayarları sıfırlanıyor...
taskkill /f /im WatchdogService.exe >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /f /im KioskLockApp.exe >nul 2>&1

reg delete "HKCU\Software\SmartBoardLock" /f >nul 2>&1
reg delete "HKLM\Software\SmartBoardLock" /f >nul 2>&1

echo.
echo [BAŞARILI] Eşleştirme verileri silindi!
echo Tahta bir sonraki açılışında yeni 6 haneli kod üretecek ve eşleşme bekleyecektir.
echo.
pause
goto MENU

:TAMAMEN_SIL
cls
echo =====================================================================
echo   DİKKAT: SINIF360 BİLGİSAYARDAN TAMAMEN KALDIRILACAK!
echo =====================================================================
echo.
set /p ONAY="Bu işlemi onaylıyor musunuz? (E/H): "
if /i not "%ONAY%"=="E" (
    echo İşlem iptal edildi.
    pause
    goto MENU
)

echo.
echo 1. Süreçler kapatılıyor...
taskkill /f /im WatchdogService.exe >nul 2>&1
timeout /t 1 /nobreak >nul
taskkill /f /im KioskLockApp.exe >nul 2>&1
taskkill /f /im TahtaUpdater.exe >nul 2>&1
taskkill /f /im TahtaRepair.exe >nul 2>&1
taskkill /f /im WatchdogService.exe >nul 2>&1
taskkill /f /im KioskLockApp.exe >nul 2>&1

echo 2. Başlangıç kayıtları kaldırılıyor...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaKilitSistemi" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaWatchdog" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaKilitSistemi" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "AkilliTahtaWatchdog" /f >nul 2>&1

echo 3. Kayıt Defteri temizleniyor...
reg delete "HKCU\Software\SmartBoardLock" /f >nul 2>&1
reg delete "HKLM\Software\SmartBoardLock" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A3B982A3-CD89-4361-8FB7-89DA4109EF89}_is1" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A3B982A3-CD89-4361-8FB7-89DA4109EF89}_is1" /f >nul 2>&1

echo 4. Sistem kısıtlamaları kaldırılıyor...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1

echo 5. Program klasörü (C:\ProgramData\AkilliTahtaKilitSistemi) siliniyor...
if exist "C:\ProgramData\AkilliTahtaKilitSistemi" (
    rmdir /s /q "C:\ProgramData\AkilliTahtaKilitSistemi" >nul 2>&1
)

echo.
echo [BAŞARILI] Sınıf360 tamamen silindi ve bilgisayar temizlendi.
echo.
pause
goto MENU

:DURUM
cls
echo =====================================================================
echo                      CANLI SİSTEM DURUMU
echo =====================================================================
echo.
echo [1] Çalışan Süreçler:
tasklist /fi "imagename eq KioskLockApp.exe" 2>nul | findstr /i "KioskLockApp.exe" || echo  - KioskLockApp.exe: DURDURULDU
tasklist /fi "imagename eq WatchdogService.exe" 2>nul | findstr /i "WatchdogService.exe" || echo  - WatchdogService.exe: DURDURULDU
tasklist /fi "imagename eq TahtaUpdater.exe" 2>nul | findstr /i "TahtaUpdater.exe" || echo  - TahtaUpdater.exe: DURDURULDU
tasklist /fi "imagename eq TahtaRepair.exe" 2>nul | findstr /i "TahtaRepair.exe" || echo  - TahtaRepair.exe: DURDURULDU

echo.
echo [2] Yüklü Klasör Durumu:
if exist "C:\ProgramData\AkilliTahtaKilitSistemi" (
    echo  - C:\ProgramData\AkilliTahtaKilitSistemi: MEVCUT
) else (
    echo  - C:\ProgramData\AkilliTahtaKilitSistemi: YOK (Silinmiş)
)

echo.
echo [3] Registry Kayıt Durumu:
reg query "HKCU\Software\SmartBoardLock" >nul 2>&1
if %errorLevel% equ 0 (
    echo  - HKCU\Software\SmartBoardLock: KAYITLI (Eşleşmiş/Ayar mevcut)
) else (
    echo  - HKCU\Software\SmartBoardLock: TEMİZ (Kayıt yok)
)

echo.
pause
goto MENU
