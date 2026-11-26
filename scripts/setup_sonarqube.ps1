# =============================================================================
# Setup & Start SonarQube Server via Docker for Windows
# =============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
Set-Location $ProjectDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[*] MEVI Dashboard - SonarQube Docker Setup" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Cek status Docker
Write-Host ""
Write-Host "[1/4] Memeriksa status Docker..." -ForegroundColor Yellow
try {
    $dockerCheck = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Docker Daemon belum berjalan!" -ForegroundColor Red
        Write-Host "Silakan buka aplikasi Docker Desktop di Windows Anda terlebih dahulu." -ForegroundColor Red
        Write-Host "Tunggu hingga icon Docker di tray berubah hijau, lalu jalankan script ini kembali." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[OK] Docker Desktop sedang berjalan." -ForegroundColor Green
} catch {
    Write-Host "[X] Docker tidak ditemukan atau belum berjalan. Buka Docker Desktop terlebih dahulu." -ForegroundColor Red
    exit 1
}

# 2. Persiapkan folder plugin dan download sonar-flutter-plugin
Write-Host ""
Write-Host "[2/4] Memeriksa plugin Flutter/Dart..." -ForegroundColor Yellow
$PluginDir = Join-Path $ProjectDir "sonarqube\plugins"
if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null
}

$PluginFile = Join-Path $PluginDir "sonar-flutter-plugin-0.5.2.jar"
if (-not (Test-Path $PluginFile)) {
    $PluginUrl = "https://github.com/insideapp-fr/sonar-flutter/releases/download/0.5.2/sonar-flutter-plugin-0.5.2.jar"
    Write-Host "Mengunduh plugin Dart/Flutter ($PluginUrl)..." -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $PluginUrl -OutFile $PluginFile -UseBasicParsing
        Write-Host "[OK] Plugin Dart/Flutter berhasil diunduh ke: $PluginFile" -ForegroundColor Green
    } catch {
        Write-Host "[!] Gagal mengunduh otomatis plugin: $_" -ForegroundColor DarkYellow
        Write-Host "Anda bisa download manual dari: $PluginUrl dan letakkan di folder: $PluginDir" -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Plugin Dart/Flutter sudah tersedia: $PluginFile" -ForegroundColor Green
}

# 3. Jalankan SonarQube Container
Write-Host ""
Write-Host "[3/4] Menjalankan container SonarQube..." -ForegroundColor Yellow
docker compose -f docker-compose.sonar.yml up -d sonarqube
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Gagal menjalankan docker compose!" -ForegroundColor Red
    exit 1
}

# 4. Tunggu SonarQube Server Ready
Write-Host ""
Write-Host "[4/4] Menunggu SonarQube server siap..." -ForegroundColor Yellow
$sonarReady = $false
$maxRetries = 40
$retryCount = 0

while (-not $sonarReady -and $retryCount -lt $maxRetries) {
    Start-Sleep -Seconds 5
    $retryCount++
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:9000/api/system/status" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.status -eq "UP") {
            $sonarReady = $true
            break
        }
        Write-Host "   Status SonarQube: $($response.status)... (mencoba $retryCount/$maxRetries)" -ForegroundColor Gray
    } catch {
        Write-Host "   Menunggu SonarQube boot up... ($retryCount/$maxRetries)" -ForegroundColor Gray
    }
}

if ($sonarReady) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "[SUKSES] SonarQube Server BERHASIL berjalan!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "1. Buka browser: http://localhost:9000" -ForegroundColor Cyan
    Write-Host "2. Login default:" -ForegroundColor Cyan
    Write-Host "   - Username : admin" -ForegroundColor White
    Write-Host "   - Password : admin" -ForegroundColor White
    Write-Host "   (Anda akan diminta mengganti password baru, misal: admin123)" -ForegroundColor DarkGray
    Write-Host "3. Buat Project Manual:" -ForegroundColor Cyan
    Write-Host "   - Klik 'Create a local project'" -ForegroundColor White
    Write-Host "   - Project display name: dashboard-mevi" -ForegroundColor White
    Write-Host "   - Project key: dashboard-mevi" -ForegroundColor White
    Write-Host "4. Generate Token analisis:" -ForegroundColor Cyan
    Write-Host "   - Pilih 'Locally' pada opsi analisis" -ForegroundColor White
    Write-Host "   - Generate Project Token (Copy token tersebut)" -ForegroundColor White
    Write-Host "5. Jalankan analisis menggunakan menu Opsi 2 atau script:" -ForegroundColor Cyan
    Write-Host "   .\scripts\run_sonar_analysis.ps1 -Token <TOKEN_ANDA>" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[!] SonarQube masih dalam proses inisialisasi. Cek status di browser http://localhost:9000" -ForegroundColor Yellow
}
