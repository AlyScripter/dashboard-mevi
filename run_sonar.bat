@echo off
setlocal
echo ==========================================================
echo MEVI Dashboard - SonarQube Runner
echo ==========================================================
echo 1. Setup dan Jalankan SonarQube Server di Docker
echo 2. Jalankan SonarScanner (Analisis Kode)
echo 3. Stop SonarQube Server
echo ==========================================================
set /p opt="Pilih opsi (1/2/3): "

if "%opt%"=="1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\setup_sonarqube.ps1"
) else if "%opt%"=="2" (
    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\run_sonar_analysis.ps1"
) else if "%opt%"=="3" (
    docker compose -f "%~dp0docker-compose.sonar.yml" down
    echo SonarQube server dihentikan.
) else (
    echo Pilihan tidak valid.
)
pause
