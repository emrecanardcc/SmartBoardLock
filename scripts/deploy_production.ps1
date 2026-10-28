# =====================================================================
# Sınıf360 Tek Tıkla Canlı Yayına Alma Motoru (Windows + Web + Veritabanı)
# =====================================================================

param(
    [string]$Version = "2.1.2"
)

$ErrorActionPreference = "Stop"

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "     Sınıf360 v$Version CANLI YAYINA ALMA KONSOLU         " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Bu işlem Mobil Mağaza Onayı (Apple/Google) geldikten sonra" -ForegroundColor White
Write-Host "Windows tahtaları, Web Admin panelini ve veritabanını" -ForegroundColor White
Write-Host "aynı saniyede CANLIYA ALIR.`n" -ForegroundColor White

$confirm = Read-Host "Mobil uygulamalar mağazalarda onaylandı mı? Yayını başlatmak istiyor musunuz? (E/H)"
if ($confirm -ne "E" -and $confirm -ne "e") {
    Write-Host "`n[İPTAL EDİLDİ] Canlı yayın başlatılmadı. Sistem beklemede." -ForegroundColor Yellow
    exit 0
}

$sshKey = "C:\Users\ardce\Downloads\ssh-key-2026-10-17.key"
$zipFile = "C:\Users\ardce\Desktop\TahtaUpdate_v$Version.zip"

if (-not (Test-Path $sshKey)) {
    Write-Host "[HATA] SSH anahtarı bulunamadı: $sshKey" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $zipFile)) {
    Write-Host "[HATA] Windows güncelleme paketi bulunamadı: $zipFile" -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------------
# ADIM 1: WINDOWS GÜNCELLEME PAKETİNİ ORACLE VM'E YÜKLE
# -------------------------------------------------------------
Write-Host "`n[1/3] Windows güncelleme paketi Oracle VM sunucusuna yükleniyor..." -ForegroundColor Cyan

scp -i $sshKey -o StrictHostKeyChecking=no $zipFile "ubuntu@130.61.78.192:/home/ubuntu/TahtaUpdate_v$Version.zip"

ssh -i $sshKey -o StrictHostKeyChecking=no ubuntu@130.61.78.192 @"
    mkdir -p /home/ubuntu/downloads
    cp /home/ubuntu/TahtaUpdate_v$Version.zip /home/ubuntu/downloads/TahtaUpdate_v$Version.zip
    sudo cp /home/ubuntu/TahtaUpdate_v$Version.zip /home/ubuntu/supabase/volumes/storage/stub/stub/updates/TahtaUpdate_v$Version.zip 2>/dev/null || true
    
    # Supabase app_versions tablosunu güncelle (Tahtalar anında bu sürümü görür)
    docker exec -i supabase-db psql -U postgres -d postgres -c "INSERT INTO public.app_versions (version_number, download_url) VALUES ('$Version', 'http://130.61.78.192:8000/storage/v1/object/public/updates/TahtaUpdate_v$Version.zip');"
"@

Write-Host "  [OK] Windows v$Version Oracle VM'e yüklendi ve tahtalar için yayınlandı." -ForegroundColor Green

# -------------------------------------------------------------
# ADIM 2: VERİTABANI MOBİL ZORUNLU GÜNCELLEMEYİ DEVREYE SOK
# -------------------------------------------------------------
Write-Host "`n[2/3] Mobil zorunlu güncelleme kuralı veritabanında aktif ediliyor..." -ForegroundColor Cyan

ssh -i $sshKey -o StrictHostKeyChecking=no ubuntu@130.61.78.192 @"
    docker exec -i supabase-db psql -U postgres -d postgres -c "UPDATE public.mobile_app_versions SET min_version = '$Version', latest_version = '$Version', is_forced = true;"
"@

Write-Host "  [OK] Mobil uygulama zorunlu güncelleme şartı aktif edildi." -ForegroundColor Green

# -------------------------------------------------------------
# ADIM 3: WEB ADMİN PANELİNİ CLOUDFLARE PAGES & VM'E YAYINLA
# -------------------------------------------------------------
Write-Host "`n[3/3] Web Admin paneli derlenip Cloudflare Pages ve VM mirror'a alınıyor..." -ForegroundColor Cyan

$webAdminDir = "C:\Projeler\AkilliTahtaSistemi\web_admin"
Push-Location $webAdminDir
try {
    flutter clean
    flutter pub get
    flutter build web --release --no-tree-shake-icons
    Copy-Item "web\_worker.js" "build\web\_worker.js" -Force
    cmd.exe /c "npx wrangler pages deploy build/web --project-name=panel-sinif360 --branch=main --commit-dirty=true"
    Write-Host "  [OK] Web Admin Cloudflare Pages üzerinde canlıya alındı." -ForegroundColor Green

    # VM Mirror Güncellemesi
    tar -czf web_admin_bundle.tar.gz -C build\web .
    scp -i $sshKey -o StrictHostKeyChecking=no web_admin_bundle.tar.gz "ubuntu@130.61.78.192:/home/ubuntu/web_admin_bundle.tar.gz"
    ssh -i $sshKey -o StrictHostKeyChecking=no ubuntu@130.61.78.192 "tar -xzf /home/ubuntu/web_admin_bundle.tar.gz -C /home/ubuntu/downloads/admin/ && chmod -R 777 /home/ubuntu/downloads/admin/ && rm /home/ubuntu/web_admin_bundle.tar.gz"
    Remove-Item "web_admin_bundle.tar.gz" -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Web Admin Oracle VM ayna sunucusuna yüklendi." -ForegroundColor Green
}
finally {
    Pop-Location
}

# -------------------------------------------------------------
# TAMAMLANDI
# -------------------------------------------------------------
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  TEBRİKLER! TÜM SİSTEM AYNI ANDA CANLIYA ALINDI!          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "1. Akıllı tahtalar otomatik olarak v$Version sürümüne güncelleniyor." -ForegroundColor White
Write-Host "2. Web Admin yeni afiş ve kilit özellikleriyle yayında." -ForegroundColor White
Write-Host "3. Mobil uygulamayı açan öğretmenler yeni sürüme yönlendiriliyor." -ForegroundColor White
Write-Host "`nÇıkmak için bir tuşa basın..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
