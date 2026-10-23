@echo off
chcp 65001 >nul
title Sınıf360 - Yeni Yayın Paketi Oluşturucu
cls
echo ==========================================================
echo       Sınıf360 YAYIN PAKETİ HAZIRLAMA ARACI
echo ==========================================================
echo Bu araç Windows Setup (.exe), Mobil APK ve Güncelleme ZIP
echo dosyalarını otomatik derleyip C:\Users\ardce\AKTS içine
echo 2.1.2(1), 2.1.2(2)... şeklinde artırarak kaydeder.
echo ==========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release_package.ps1"
echo.
echo İşlem tamamlandı. Çıkmak için bir tuşa basın...
pause >nul
