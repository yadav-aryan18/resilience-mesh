#!/bin/bash
set -e

echo "🛠️  Setting up ResilienceMesh Backend..."

# Check Python
python3 --version || { echo "Python 3 not found"; exit 1; }

# Create venv
python3 -m venv venv
source venv/bin/activate

# Install deps
pip install --upgrade pip
pip install -r backend/requirements.txt

# Pull Ollama model (requires Ollama installed)
if command -v ollama &> /dev/null; then
    echo "🧠 Pulling Gemma 4 12B..."
    ollama pull gemma4:12b
else
    echo "⚠️  Ollama not found. Install from https://ollama.com then run: ollama pull gemma4:12b"
fi

# Index RAG documents
echo "📚 Indexing emergency protocols..."
cd rag
python ingest.py --reset

echo "✅ Backend setup complete."
echo "   Start server: cd backend && source ../venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 8000"
