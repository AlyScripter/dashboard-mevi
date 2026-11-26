param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "sqp_116f0f0020a8e0a8bfb629e3f79f9d1c861bf6c9",
    [switch]$SkipFlutter
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
Set-Location $ProjectDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[*] MEVI Dashboard - SonarScanner Docker Runner" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Jalankan flutter analyze dan coverage jika ada flutter
if (-not $SkipFlutter) {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "[1/3] Menjalankan flutter analyze..." -ForegroundColor Yellow
        try {
            cmd /c "flutter analyze --no-pub > flutter_analyzer_report.txt 2>&1"
            Write-Host "[OK] flutter analyze selesai, disimpan ke flutter_analyzer_report.txt." -ForegroundColor Green
        } catch {
            Write-Host "[!] Warning saat flutter analyze, melanjutkan..." -ForegroundColor DarkYellow
        }
        
        Write-Host ""
        Write-Host "[2/3] Menjalankan unit test dan coverage (jika ada)..." -ForegroundColor Yellow
        try {
            flutter test --coverage
            Write-Host "[OK] Laporan coverage lcov.info siap di: coverage/lcov.info" -ForegroundColor Green
        } catch {
            Write-Host "[!] Test gagal atau belum ada test, melanjutkan proses scan..." -ForegroundColor DarkYellow
        }
    } else {
        Write-Host ""
        Write-Host "[Info] Flutter CLI tidak terdeteksi di PATH host, melewati tahap flutter analyze." -ForegroundColor DarkGray
    }
} else {
    Write-Host ""
    Write-Host "[Info] Melewati tahap Flutter (SkipFlutter aktif)." -ForegroundColor DarkGray
}

# 2. Cek Token
if (-not $Token) {
    if ($env:SONAR_TOKEN) {
        $Token = $env:SONAR_TOKEN
        Write-Host ""
        Write-Host "[Token] Menggunakan SONAR_TOKEN dari environment variable." -ForegroundColor Green
    } else {
        Write-Host ""
        $Token = Read-Host "Masukkan SonarQube Project Token"
    }
}

if (-not $Token) {
    Write-Host "[X] Token tidak boleh kosong." -ForegroundColor Red
    exit 1
}

# 3. Jalankan SonarScanner via Docker
Write-Host ""
Write-Host "[3/3] Menjalankan SonarScanner via Docker Container..." -ForegroundColor Yellow
Write-Host "Menghubungkan ke server SonarQube di container..." -ForegroundColor Cyan

$dockerCmd = @(
    "run", "--rm",
    "--network", "dashboard-mevi_sonar-network",
    "-v", "${ProjectDir}:/usr/src",
    "-e", "SONAR_HOST_URL=http://sonarqube-mevi:9000",
    "-e", "SONAR_TOKEN=$Token",
    "sonarsource/sonar-scanner-cli:latest"
)

try {
    & docker @dockerCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Docker bridge scan exited with code $LASTEXITCODE"
    }
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "[SUKSES] Analisis SonarQube Selesai!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Lihat hasil analisis lengkap di dashboard browser Anda:" -ForegroundColor Cyan
    Write-Host "URL: http://localhost:9000/dashboard?id=dashboard-mevi" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "[!] Terjadi kendala saat scan: $_" -ForegroundColor Red
}
