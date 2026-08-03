@echo off
title ResilienceMesh — Command Node Launcher
echo =====================================================================
echo 🛡️  ResilienceMesh — Tier 2 Laptop Command Node Launcher
echo =====================================================================

cd /d "%~dp0"

:: 1. Check & Build Frontend if needed
if not exist "backend\frontend\dist\" (
    echo [1/3] Building Vite React frontend dashboard...
    cd backend\frontend
    call npm install
    call npm run build
    cd ..\..
) else (
    echo [1/3] Frontend build verified.
)

:: 2. Open Browser in background once server health check passes
echo [2/3] Preparing automated health check and browser launch...
start "" powershell -NoProfile -ExecutionPolicy Bypass -Command "$ready = $false; for ($i=0; $i -lt 60; $i++) { try { $r = Invoke-WebRequest -Uri 'http://localhost:8000/api/health' -UseBasicParsing -TimeoutSec 1; if ($r.StatusCode -eq 200) { $ready = $true; break } } catch {}; Start-Sleep -Milliseconds 500 }; if ($ready) { Start-Process 'http://localhost:8000' }"

:: 3. Launch FastAPI Command Server
echo [3/3] Starting Command Node Server on http://localhost:8000 ...
echo =====================================================================
cd backend
python main.py

pause
