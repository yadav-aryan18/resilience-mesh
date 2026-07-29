#!/bin/bash
set -e

echo "🧪 Running ResilienceMesh Backend Test Suite..."

cd backend

if which pytest > /dev/null 2>&1; then
    PYTHONPATH=. pytest tests/ -v
elif which uv > /dev/null 2>&1; then
    PYTHONPATH=. uv run python -m unittest discover -s tests -p "test_*.py" -v
else
    PYTHONPATH=. python3 -m unittest discover -s tests -p "test_*.py" -v
fi

echo "✅ All backend tests passed successfully!"
