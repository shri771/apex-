#!/data/data/com.termux/files/usr/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "==> Ollama already running, skipping start"
else
    echo "==> Starting Ollama in background..."
    ollama serve &
    echo "==> Waiting for Ollama on :11434..."
    until curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do
        sleep 1
    done
fi
echo "==> Ollama is up"

echo "==> Starting FastAPI backend..."
cd "$REPO_DIR"
exec uvicorn backend.main:app --host 127.0.0.1 --port 8000
