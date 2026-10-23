# =====================================================================
# Sınıf360 / AKTS Sürüm Paketleme ve Yayın Hazırlama Motoru
# Hedef Dizin: C:\Users\ardce\AKTS
# İsimlendirme Formatı: 2.1.2(1), 2.1.2(2), ...
# =====================================================================

param(
    [string]$BaseVersion = "2.1.2",
    [int]$Iteration = 0, # 0 = Otomatik tespit et (en son + 1)
    [switch]$SkipApkBuild, # Mevcut APK'yı kullan
    [switch]$SkipWindowsBuild # Mevcut publish klasörünü kullan
)

$ErrorActionPreference = "Stop"

$AktsRoot = "C:\Users\ardce\AKTS"
if (-not (Test-Path $AktsRoot)) {
    New-Item -ItemType Directory -Force -Path $AktsRoot | Out-Null
}

# -------------------------------------------------------------
# ADIM 1: SÜRÜM VE İTERASYON NUMARASINI BELİRLE
# -------------------------------------------------------------
if ($Iteration -le 0) {
    # Mevcut klasörleri tara (Örn: 2.1.2(1), 2.1.2(2))
    $existing = Get-ChildItem -Path $AktsRoot -Directory | Where-Object {
        $_.Name -match "^$([regex]::Escape($BaseVersion))\((\d+)\)$"
    }

    if ($existing.Count -gt 0) {
        $maxIteration = ($existing | ForEach-Object {
            if ($_.Name -match "^$([regex]::Escape($BaseVersion))\((\d+)\)$") {
                [int]$matches[1]
            }
        } | Measure-Object -Maximum).Maximum
        $Iteration = $maxIteration + 1
    }
    else {
        $Iteration = 1
    }
}

$VersionTag = "$BaseVersion($Iteration)"
$TargetDir = Join-Path $AktsRoot $VersionTag

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "     Sınıf360 YAYIN PAKETLEME MOTORU: $VersionTag          " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Hedef Klasör: $TargetDir" -ForegroundColor White

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

$ProjectRoot = "C:\Projeler\AkilliTahtaSistemi"
$MobileDir = Join-Path $ProjectRoot "mobile\TeacherMobile"
$WindowsDist = Join-Path $ProjectRoot "dist\v2.1.2_publish"
$InnoCompiler = "C:\Program Files\Inno Setup 7\ISCC.exe"
$InnoScript = Join-Path $ProjectRoot "windows\Sinif360_Setup.iss"

# -------------------------------------------------------------
# ADIM 1.5: WINDOWS PROJELERİNİ DERLE VE YAYINA HAZIRLA
# -------------------------------------------------------------
if (-not $SkipWindowsBuild) {
    Write-Host "`n[*] Windows C# projeleri Release modunda derlenip yayına hazırlanıyor..." -ForegroundColor Cyan
    & dotnet publish (Join-Path $ProjectRoot "windows\KioskLockApp\KioskLockApp.csproj") -c Release -r win-x64 --no-self-contained -o $WindowsDist | Out-Null
    & dotnet publish (Join-Path $ProjectRoot "windows\ConsoleApp1\WatchdogService.csproj") -c Release -r win-x64 --no-self-contained -o $WindowsDist | Out-Null
    & dotnet publish (Join-Path $ProjectRoot "windows\TahtaUpdater\TahtaUpdater.csproj") -c Release -r win-x64 --no-self-contained -o $WindowsDist | Out-Null
    & dotnet publish (Join-Path $ProjectRoot "windows\TahtaRepair\TahtaRepair.csproj") -c Release -r win-x64 --no-self-contained -o $WindowsDist | Out-Null
    Write-Host "  [OK] Windows ikili dosyaları güncellendi." -ForegroundColor Green
}

# -------------------------------------------------------------
# ADIM 2: WINDOWS GÜNCELLEME ZIP PAKETİNİ OLUŞTUR
# -------------------------------------------------------------
Write-Host "`n[1/3] Windows Güncelleme ZIP paketi hazırlanıyor..." -ForegroundColor Cyan
$ZipFileName = "TahtaUpdate_v$VersionTag.zip"
$TargetZip = Join-Path $TargetDir $ZipFileName

if (Test-Path $TargetZip) { Remove-Item $TargetZip -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($WindowsDist, $TargetZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$zipSizeMb = [math]::Round((Get-Item $TargetZip).Length / 1MB, 2)
Write-Host "  [OK] ZIP Paketi Hazır: $ZipFileName ($zipSizeMb MB)" -ForegroundColor Green

# -------------------------------------------------------------
# ADIM 3: INNO SETUP İLE WINDOWS KURULUM (.EXE) DOSYASINI DERLE
# -------------------------------------------------------------
Write-Host "`n[2/3] Inno Setup ile Windows Kurulum (.exe) derleniyor..." -ForegroundColor Cyan
$SetupFileName = "Sinif360_v$($VersionTag)_Setup"
$TargetSetupExe = Join-Path $TargetDir "$SetupFileName.exe"

if (-not (Test-Path $InnoCompiler)) {
    throw "Inno Setup derleyicisi bulunamadı: $InnoCompiler"
}

$isccArgs = @(
    "--output-dir=$TargetDir",
    "--output-filename=$SetupFileName",
    "-dMyAppVersion=$VersionTag",
    $InnoScript
)

& $InnoCompiler $isccArgs | Out-Null

if (-not (Test-Path $TargetSetupExe)) {
    throw "Setup derlemesi başarısız oldu: $TargetSetupExe üretilemedi!"
}

$setupSizeMb = [math]::Round((Get-Item $TargetSetupExe).Length / 1MB, 2)
Write-Host "  [OK] Setup Dosyası Hazır: $SetupFileName.exe ($setupSizeMb MB)" -ForegroundColor Green

# -------------------------------------------------------------
# ADIM 4: MOBİL RELEASE APK DOSYASINI HAZIRLA
# -------------------------------------------------------------
Write-Host "`n[3/3] Mobil Öğretmen APK dosyası hazırlanıyor..." -ForegroundColor Cyan
$BuiltApkPath = Join-Path $MobileDir "build\app\outputs\flutter-apk\app-release.apk"
$TargetApkName = "Sinif360_TeacherMobile_v$VersionTag.apk"
$TargetApk = Join-Path $TargetDir $TargetApkName

if (-not $SkipApkBuild -or -not (Test-Path $BuiltApkPath)) {
    Write-Host "  Flutter APK derlemesi yapılıyor (release)..." -ForegroundColor Yellow
    Push-Location $MobileDir
    try {
        & flutter build apk --release | Out-Null
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $BuiltApkPath)) {
    throw "Release APK bulunamadı: $BuiltApkPath"
}

Copy-Item $BuiltApkPath $TargetApk -Force
$apkSizeMb = [math]::Round((Get-Item $TargetApk).Length / 1MB, 2)
Write-Host "  [OK] APK Dosyası Hazır: $TargetApkName ($apkSizeMb MB)" -ForegroundColor Green

# -------------------------------------------------------------
# ADIM 5: SÜRÜM BİLGİ DOSYASI (RELEASE_INFO.TXT) OLUŞTUR
# -------------------------------------------------------------
$hashSetup = (Get-FileHash -Path $TargetSetupExe -Algorithm SHA256).Hash
$hashApk = (Get-FileHash -Path $TargetApk -Algorithm SHA256).Hash
$hashZip = (Get-FileHash -Path $TargetZip -Algorithm SHA256).Hash
$dateNow = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$infoContent = @"
=====================================================================
Sınıf360 Yayın Paketi Bilgisi: v$VersionTag
Oluşturulma Tarihi: $dateNow
Hedef Dizin: $TargetDir
=====================================================================

1. Windows Kurulum Dosyası (Setup):
   Dosya Adı: $SetupFileName.exe
   Boyut    : $setupSizeMb MB
   SHA-256  : $hashSetup

2. Mobil Öğretmen Uygulaması (APK):
   Dosya Adı: $TargetApkName
   Boyut    : $apkSizeMb MB
   SHA-256  : $hashApk

3. Akıllı Tahta Otomatik Güncelleme (ZIP):
   Dosya Adı: $ZipFileName
   Boyut    : $zipSizeMb MB
   SHA-256  : $hashZip

=====================================================================
"@

Set-Content -Path (Join-Path $TargetDir "RELEASE_INFO.txt") -Value $infoContent -Encoding UTF8

# Klasörü Windows Explorer ile aç
Start-Process "explorer.exe" $TargetDir

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  TEBRİKLER! TÜM YAYIN DOSYALARI HAZIRLANDI: $VersionTag   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Konum: $TargetDir" -ForegroundColor White
Write-Host "1. $SetupFileName.exe ($setupSizeMb MB)" -ForegroundColor Cyan
Write-Host "2. $TargetApkName ($apkSizeMb MB)" -ForegroundColor Cyan
Write-Host "3. $ZipFileName ($zipSizeMb MB)" -ForegroundColor Cyan
