#!/usr/bin/env bash
# =====================================================================
# ResilienceMesh — One-Click Command Node Launcher (Linux / macOS)
# =====================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "====================================================================="
echo "🛡️  ResilienceMesh — Tier 2 Laptop Command Node Launcher"
echo "====================================================================="

# 1. Check & Start Ollama
echo "[1/4] Checking Ollama service status..."
if ! command -v ollama &> /dev/null; then
    echo "⚠️  Ollama is not installed. Please install Ollama from https://ollama.com"
else
    if ! pgrep -x "ollama" > /dev/null && ! curl -s http://localhost:11434/api/tags > /dev/null; then
        echo "🚀 Starting Ollama background daemon..."
        ollama serve > /dev/null 2>&1 &
        sleep 2
    else
        echo "✅ Ollama service is already running."
    fi
fi

# 2. Check & Pull Gemma 4 Model Target
echo "[2/4] Verifying Gemma 4 model target..."
if command -v ollama &> /dev/null; then
    if ! ollama list | grep -q "gemma"; then
        echo "📥 Pulling gemma4:12b model (this may take a few minutes on first run)..."
        ollama pull gemma4:12b || echo "⚠️  Could not pull gemma4:12b. Please pull manually via: ollama pull gemma4:12b"
    else
        echo "✅ Gemma model is ready in Ollama."
    fi
fi

# 3. Verify Frontend Dist Build
echo "[3/4] Checking Web Dashboard build..."
if [ ! -d "backend/frontend/dist" ]; then
    echo "📦 Building Vite React frontend..."
    if command -v npm &> /dev/null; then
        (cd backend/frontend && npm install && npm run build)
    else
        echo "⚠️  npm not found. Serving static fallback if available."
    fi
else
    echo "✅ Frontend build verified."
fi

# 4. Launch FastAPI Command Node & Open Browser
echo "[4/4] Starting Command Node Server on http://0.0.0.0:8000..."
echo "====================================================================="
echo "🌐 Command Dashboard available at: http://localhost:8000"
echo "====================================================================="

# Open default browser once the server health check passes
(
    for i in {1..60}; do
        if curl -s -f http://localhost:8000/api/health > /dev/null 2>&1; then
            if command -v xdg-open &> /dev/null; then
                xdg-open "http://localhost:8000" &> /dev/null || true
            elif command -v open &> /dev/null; then
                open "http://localhost:8000" &> /dev/null || true
            fi
            exit 0
        fi
        sleep 0.5
    done
) &

cd backend
python3 main.py
