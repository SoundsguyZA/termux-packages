#!/data/data/com.termux/files/usr/bin/bash
# Post-restore native Termux setup.
# Run this AFTER termux-restore completes and Termux restarts.
#
# What this does:
#   1. Installs Claude Code natively in Termux (no proot needed)
#   2. Wires Aluna Memory MCP into ~/.claude.json
#   3. Installs Ollama (ARM64 binary, CPU-only)
#   4. Runs a quick verification pass

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; }
info() { echo -e "  ${BLUE}>>>>${NC}  $1"; }
die()  { echo -e "${RED}ERR${NC} $1"; exit 1; }

echo ""
echo "===== KIRA NATIVE TERMUX SETUP ====="
echo ""

# ── 1. NODE.JS ──────────────────────────────────────────────────────────────
info "Checking Node.js..."
if ! command -v node &>/dev/null; then
  info "Node.js not found — installing..."
  pkg install -y nodejs
fi
NODE_VER=$(node --version)
pass "Node.js: $NODE_VER"

# ── 2. CLAUDE CODE (NATIVE TERMUX) ──────────────────────────────────────────
info "Installing Claude Code natively in Termux..."
npm install -g @anthropic-ai/claude-code 2>&1 | tail -3

CLAUDE_VER=$(claude --version 2>/dev/null | head -1)
if [ -n "$CLAUDE_VER" ]; then
  pass "Claude Code: $CLAUDE_VER"
else
  die "Claude Code install failed. Check npm output above."
fi

# ── 3. ALUNA MEMORY MCP ─────────────────────────────────────────────────────
info "Configuring Aluna Memory MCP in ~/.claude.json..."
CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ] && grep -q "mcp.alunaafrica.cloud" "$CLAUDE_JSON" 2>/dev/null; then
  pass "Aluna Memory MCP: already wired in ~/.claude.json (restored from backup)"
else
  warn "~/.claude.json missing or MCP not wired — checking if backup had it..."

  # Prompt for token
  echo ""
  echo "  Get your MCP token from Notion:"
  echo "  Page: 'Kira — Aluna Memory MCP Instructions'"
  echo "  URL format: https://mcp.alunaafrica.cloud/<TOKEN>/mcp"
  echo ""
  read -p "  Paste your MCP token (the part between /c1a-... and /mcp): " MCP_TOKEN

  if [ -z "$MCP_TOKEN" ]; then
    warn "Skipping MCP config — re-run this script and paste token when prompted"
  else
    MCP_URL="https://mcp.alunaafrica.cloud/${MCP_TOKEN}/mcp"

    # Write ~/.claude.json with user-scope MCP entry
    cat > "$CLAUDE_JSON" <<MCPEOF
{
  "mcpServers": {
    "Aluna_Memory": {
      "type": "http",
      "url": "${MCP_URL}"
    }
  }
}
MCPEOF
    pass "Aluna Memory MCP: wired at $MCP_URL"
    info "Verify with: cat ~/.claude.json"
  fi
fi

# ── 4. OLLAMA ────────────────────────────────────────────────────────────────
info "Checking Ollama..."
if command -v ollama &>/dev/null; then
  OLLAMA_VER=$(ollama --version 2>/dev/null | head -1)
  pass "Ollama: already installed — $OLLAMA_VER"
else
  info "Installing Ollama (ARM64 binary)..."
  ARCH=$(uname -m)
  [ "$ARCH" = "aarch64" ] || die "Expected aarch64, got $ARCH"

  OLLAMA_VERSION=$(curl -sf https://api.github.com/repos/ollama/ollama/releases/latest \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
  [ -n "$OLLAMA_VERSION" ] || die "Could not fetch Ollama version — check internet"

  info "Downloading Ollama $OLLAMA_VERSION..."
  curl -L --progress-bar \
    "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-arm64" \
    -o "$PREFIX/bin/ollama"
  chmod +x "$PREFIX/bin/ollama"

  OLLAMA_VER=$(ollama --version 2>/dev/null | head -1)
  if [ -n "$OLLAMA_VER" ]; then
    pass "Ollama: $OLLAMA_VER"
  else
    die "Ollama binary installed but failed to run. Try: $PREFIX/bin/ollama --version"
  fi
fi

# Start ollama serve in background if not already running
if ! pgrep -f "ollama serve" &>/dev/null; then
  info "Starting ollama serve on port 11434..."
  OLLAMA_HOST=127.0.0.1:11434 ollama serve &>/tmp/ollama.log &
  sleep 3
fi

if curl -sf http://127.0.0.1:11434 &>/dev/null; then
  pass "Ollama server: running on port 11434"
else
  warn "Ollama server: may still be starting — check: curl http://127.0.0.1:11434"
fi

# Pull starter model
echo ""
echo "  Recommended models (CPU-only, Pura 80 Pro):"
echo "    tinyllama  ~637MB   fastest"
echo "    phi3:mini  ~2.2GB   balanced"
echo "    llama3.2:3b ~2GB    best quality"
echo ""
read -p "  Pull a model now? Enter name or press Enter to skip: " MODEL_CHOICE
if [ -n "$MODEL_CHOICE" ]; then
  info "Pulling $MODEL_CHOICE..."
  ollama pull "$MODEL_CHOICE"
  pass "Model ready: $MODEL_CHOICE"
fi

# ── 5. VERIFICATION ──────────────────────────────────────────────────────────
echo ""
echo "===== VERIFICATION ====="
echo ""

node --version &>/dev/null && pass "Node.js" || fail "Node.js"
claude --version &>/dev/null && pass "Claude Code (native Termux)" || fail "Claude Code"
grep -q "mcp.alunaafrica.cloud" "$HOME/.claude.json" 2>/dev/null && pass "Aluna Memory MCP" || warn "Aluna Memory MCP (check ~/.claude.json)"
ollama --version &>/dev/null && pass "Ollama" || fail "Ollama"
curl -sf http://127.0.0.1:11434 &>/dev/null && pass "Ollama server" || warn "Ollama server (run: ollama serve)"

# Check if skills survived backup restore
SKILL_COUNT=$(ls "$HOME/.claude/commands/" 2>/dev/null | wc -l)
if [ "$SKILL_COUNT" -gt 0 ]; then
  pass "Claude Code skills: $SKILL_COUNT files restored"
  ls "$HOME/.claude/commands/" | sed 's/^/             /'
else
  warn "Claude Code skills: ~/.claude/commands/ empty — re-add skills manually"
fi

echo ""
echo "===== DONE ====="
echo ""
echo "Next steps:"
echo "  Start Claude Code:   claude"
echo "  Chat with Ollama:    ollama run ${MODEL_CHOICE:-tinyllama}"
echo "  Ollama logs:         tail -f /tmp/ollama.log"
echo ""
