# =====================================================================
# Sınıf360 GitHub Secrets Otomatik Yükleme Aracı
# =====================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Sınıf360 CI/CD Otomasyon Anahtarları GitHub'a Yükleniyor" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ghCli = "C:\Program Files\GitHub CLI\gh.exe"
if (-not (Test-Path $ghCli)) {
    $ghCli = (Get-Command gh -ErrorAction SilentlyContinue).Source
}

if (-not $ghCli) {
    Write-Host "[HATA] GitHub CLI (gh) bulunamadı. Lütfen 'winget install GitHub.cli' çalıştırın." -ForegroundColor Red
    exit 1
}

# 1. Apple App Store Connect Anahtarı
$p8File = "C:\Users\ardce\OneDrive\Desktop\AuthKey_9CPAA97QY7.p8"
if (Test-Path $p8File) {
    $p8Bytes = [System.IO.File]::ReadAllBytes($p8File)
    $p8Base64 = [Convert]::ToBase64String($p8Bytes)
    $p8Base64 | & $ghCli secret set APP_STORE_KEY_BASE64
    Write-Host "[OK] APP_STORE_KEY_BASE64 yüklendi." -ForegroundColor Green
} else {
    Write-Host "[UYARI] AuthKey_9CPAA97QY7.p8 bulunamadı!" -ForegroundColor Yellow
}

"9CPAA97QY7" | & $ghCli secret set APP_STORE_KEY_ID
Write-Host "[OK] APP_STORE_KEY_ID yüklendi." -ForegroundColor Green

"37cfcb1d-908a-4cba-922a-057b008cc424" | & $ghCli secret set APP_STORE_ISSUER_ID
Write-Host "[OK] APP_STORE_ISSUER_ID yüklendi." -ForegroundColor Green

# 2. Android Keystore ve Properties
$jksFile = "C:\Users\ardce\OneDrive\Desktop\Sinif360_Sifre_ve_Anahtar_Yedekleri\Sinif360_Sifre_ve_Anahtar_Yedekleri\android\upload-keystore.jks"
if (Test-Path $jksFile) {
    $jksBytes = [System.IO.File]::ReadAllBytes($jksFile)
    $jksBase64 = [Convert]::ToBase64String($jksBytes)
    $jksBase64 | & $ghCli secret set ANDROID_KEYSTORE_BASE64
    Write-Host "[OK] ANDROID_KEYSTORE_BASE64 yüklendi." -ForegroundColor Green
}

$propFile = "C:\Users\ardce\OneDrive\Desktop\Sinif360_Sifre_ve_Anahtar_Yedekleri\Sinif360_Sifre_ve_Anahtar_Yedekleri\android\key.properties"
if (Test-Path $propFile) {
    Get-Content $propFile -Raw | & $ghCli secret set ANDROID_KEY_PROPERTIES
    Write-Host "[OK] ANDROID_KEY_PROPERTIES yüklendi." -ForegroundColor Green
}

# 3. Mobile .env
$envFile = "C:\Projeler\AkilliTahtaSistemi\mobile\TeacherMobile\.env"
if (Test-Path $envFile) {
    Get-Content $envFile -Raw | & $ghCli secret set MOBILE_ENV
    Write-Host "[OK] MOBILE_ENV yüklendi." -ForegroundColor Green
}

# 4. Oracle VM SSH Key
$sshKeyFile = "C:\Users\ardce\Downloads\ssh-key-2026-10-17.key"
if (Test-Path $sshKeyFile) {
    Get-Content $sshKeyFile -Raw | & $ghCli secret set ORACLE_SSH_KEY
    Write-Host "[OK] ORACLE_SSH_KEY yüklendi." -ForegroundColor Green
}

Write-Host "`n[BAŞARILI] Tüm anahtarlar GitHub şifreli kasasına yüklendi!" -ForegroundColor Green
Write-Host "Artık GitHub üzerinden tag atıldığında tüm sistem otomatik derlenip yüklenecek." -ForegroundColor Cyan
