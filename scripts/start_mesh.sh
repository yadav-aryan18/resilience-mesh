#!/bin/bash

echo "🚀 Starting ResilienceMesh Command Node..."

# Start Ollama if not running
if ! pgrep -x "ollama" > /dev/null; then
    echo "🧠 Starting Ollama..."
    ollama serve &
    sleep 3
fi

# Start backend
cd backend
source ../venv/bin/activate

echo "🌐 Starting FastAPI on 0.0.0.0:8000"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
