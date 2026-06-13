#!/data/data/com.termux/files/usr/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Starting Ollama in background..."
ollama serve &
OLLAMA_PID=$!

echo "==> Waiting for Ollama on :11434..."
until curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do
    sleep 1
done
echo "==> Ollama is up (pid $OLLAMA_PID)"

echo "==> Starting FastAPI backend..."
cd "$REPO_DIR"
exec uvicorn backend.main:app --host 127.0.0.1 --port 8000
