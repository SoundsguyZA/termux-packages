#!/data/data/com.termux/files/usr/bin/bash
# Install Ollama natively on Termux (ARM64 Linux binary).
# Runs CPU-only on Android — no GPU acceleration without root.
# Practical models on Pura 80 Pro (Kirin 9020, ~12GB RAM): llama3.2:3b, phi3:mini, tinyllama

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}>>>${NC} $1"; }
warn() { echo -e "${YELLOW}!  ${NC} $1"; }
die()  { echo -e "${RED}ERR${NC} $1"; exit 1; }

echo ""
echo "===== OLLAMA INSTALL FOR TERMUX (ARM64) ====="
echo ""
warn "CPU-only inference. No GPU on Android without root."
warn "Stick to models ≤ 3B params for usable speed."
echo ""

# Check arch
ARCH=$(uname -m)
[ "$ARCH" = "aarch64" ] || die "This script requires ARM64 (aarch64). Detected: $ARCH"

# Dependencies
info "Installing dependencies..."
pkg install -y curl proot 2>/dev/null || true

# Fetch latest Ollama ARM64 release URL
info "Fetching latest Ollama release..."
OLLAMA_VERSION=$(curl -s https://api.github.com/repos/ollama/ollama/releases/latest \
  | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/')

[ -n "$OLLAMA_VERSION" ] || die "Could not determine latest Ollama version. Check internet connection."
info "Latest version: $OLLAMA_VERSION"

DOWNLOAD_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-arm64"

# Download
info "Downloading Ollama binary..."
curl -L --progress-bar "$DOWNLOAD_URL" -o "$PREFIX/bin/ollama"
chmod +x "$PREFIX/bin/ollama"

# Verify
INSTALLED_VER=$(ollama --version 2>/dev/null | head -1)
if [ -n "$INSTALLED_VER" ]; then
  echo -e "  ${GREEN}PASS${NC}  Ollama installed: $INSTALLED_VER"
else
  die "Binary installed but 'ollama --version' failed. Try running manually: $PREFIX/bin/ollama --version"
fi

# Create Ollama home (models stored here)
OLLAMA_HOME="$HOME/.ollama"
mkdir -p "$OLLAMA_HOME"

# Start ollama serve in background
info "Starting ollama serve in background..."
OLLAMA_HOST=127.0.0.1:11434 ollama serve &>/tmp/ollama.log &
OLLAMA_PID=$!
echo "  PID: $OLLAMA_PID — logs at /tmp/ollama.log"
sleep 3

# Check if serving
if curl -s http://127.0.0.1:11434 &>/dev/null; then
  echo -e "  ${GREEN}PASS${NC}  Ollama server running on port 11434"
else
  warn "Server may still be starting. If it fails, run manually: ollama serve"
fi

# Pull starter model
echo ""
echo "Pull a starter model? (recommended: llama3.2:3b ~2GB, phi3:mini ~2.2GB, tinyllama ~637MB)"
read -p "Model to pull [tinyllama]: " MODEL_CHOICE
MODEL_CHOICE="${MODEL_CHOICE:-tinyllama}"

info "Pulling $MODEL_CHOICE (may take several minutes on mobile data)..."
ollama pull "$MODEL_CHOICE"

echo ""
echo "===== DONE ====="
echo ""
echo "Quick commands:"
echo "  Start server:  ollama serve"
echo "  Chat:          ollama run $MODEL_CHOICE"
echo "  List models:   ollama list"
echo "  Stop server:   kill \$(pgrep -f 'ollama serve')"
echo ""
echo "Models stored at: $OLLAMA_HOME/models"
echo ""
warn "To auto-start Ollama at Termux launch, add to ~/.bashrc:"
echo "  OLLAMA_HOST=127.0.0.1:11434 ollama serve &>/tmp/ollama.log &"
echo ""
