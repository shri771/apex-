#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "==> Updating packages..."
pkg update -y && pkg upgrade -y

echo "==> Installing system dependencies..."
pkg install python git clang libxml2 libxslt -y

echo "==> Installing Python requirements..."
pip install -r ~/iq-hack/backend/requirements.txt

echo "==> Pulling Ollama phi3:mini model..."
ollama pull phi3:mini

echo "==> Setup complete. Run: bash ~/iq-hack/scripts/start.sh"
