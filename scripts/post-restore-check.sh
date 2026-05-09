#!/data/data/com.termux/files/usr/bin/bash
# Verification script — run after restoring from backup + running setup-native-termux.sh
#
# Restore command (run first, in fresh Termux):
#   termux-setup-storage
#   termux-restore /storage/emulated/0/Download/APKs/termux-backup.tar.gz

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; }

echo ""
echo "===== KIRA POST-RESTORE VERIFICATION ====="
echo ""

# Node.js
NODE_VER=$(node --version 2>/dev/null)
if [ -n "$NODE_VER" ]; then
  pass "Node.js: $NODE_VER"
else
  fail "Node.js: not found — run: pkg install nodejs"
fi

# Claude Code
CLAUDE_VER=$(claude --version 2>/dev/null | head -1)
if [ -n "$CLAUDE_VER" ]; then
  pass "Claude Code: $CLAUDE_VER"
else
  fail "Claude Code: not found — run: npm install -g @anthropic-ai/claude-code"
fi

# Claude Code skills (veritas-motherlode + others)
SKILL_DIR="$HOME/.claude/commands"
if [ -d "$SKILL_DIR" ] && [ "$(ls -A $SKILL_DIR 2>/dev/null)" ]; then
  SKILL_COUNT=$(ls "$SKILL_DIR" | wc -l)
  pass "Skills: $SKILL_COUNT files in ~/.claude/commands/"
  ls "$SKILL_DIR" | sed 's/^/         /'
else
  fail "Skills: ~/.claude/commands/ is empty or missing — check backup"
fi

# Aluna Memory MCP config
CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$CLAUDE_JSON" ] && grep -q "mcp.alunaafrica.cloud" "$CLAUDE_JSON" 2>/dev/null; then
  pass "Aluna Memory MCP: wired in ~/.claude.json"
else
  fail "Aluna Memory MCP: not found in ~/.claude.json"
  echo "         Get token from Notion: 🤖 Kira — Aluna Memory MCP Instructions"
  echo "         URL: https://mcp.alunaafrica.cloud/<TOKEN>/mcp"
fi

# DroidClaw files
if [ -f "$HOME/droidclaw/index.js" ]; then
  pass "DroidClaw: ~/droidclaw/ present"
else
  fail "DroidClaw: not found — clone: git clone https://github.com/levilyf/droidclaw ~/droidclaw"
fi

# DroidClaw config
if [ -f "$HOME/.droidclaw/config.json" ]; then
  pass "DroidClaw config: ~/.droidclaw/config.json present"
else
  warn "DroidClaw config: ~/.droidclaw/config.json missing — run setup wizard: cd ~/droidclaw && node setup.js"
fi

# gstack
if [ -d "$HOME/gstack" ] && [ -f "$HOME/gstack/gstack" ]; then
  GSTACK_VER=$($HOME/gstack/gstack --version 2>/dev/null | head -1)
  pass "gstack: present${GSTACK_VER:+ — $GSTACK_VER}"
elif [ -d "$HOME/gstack" ]; then
  warn "gstack: ~/gstack/ exists but binary not found — may need setup"
else
  fail "gstack: not found — clone: git clone https://github.com/SoundsguyZA/gstack ~/gstack"
fi

# proot-distro + Ubuntu
if command -v proot-distro &>/dev/null; then
  if proot-distro list 2>/dev/null | grep -q "ubuntu"; then
    pass "proot-distro: installed, Ubuntu rootfs present"
  else
    warn "proot-distro: installed but Ubuntu not found — run: proot-distro install ubuntu"
  fi
else
  fail "proot-distro: not installed — run: pkg install proot-distro"
fi

# CLAUDE.md
GLOBAL_MD="$HOME/.claude/CLAUDE.md"
UBUNTU_MD="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu/root/.claude/CLAUDE.md"
if [ -f "$GLOBAL_MD" ]; then
  pass "~/.claude/CLAUDE.md: present (VERITAS Termux context)"
else
  warn "~/.claude/CLAUDE.md: missing — recreate from Notion: CLAUDE.md — Environment & Skills"
fi
if [ -f "$UBUNTU_MD" ]; then
  pass "/root/.claude/CLAUDE.md: present (VERITAS Ubuntu context)"
else
  warn "/root/.claude/CLAUDE.md: missing (only matters after proot Ubuntu restore)"
fi

# context-mode plugin
PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/context-mode"
if [ -d "$PLUGIN_DIR" ]; then
  pass "context-mode plugin: present"
else
  warn "context-mode plugin: missing — install inside Claude Code: /plugin marketplace add mksglu/context-mode"
fi

# VPS reachability
echo ""
echo "  Checking VPS connectivity..."
if curl -s --max-time 5 "https://mcp.alunaafrica.cloud" &>/dev/null; then
  pass "VPS / Aluna Memory MCP: reachable"
else
  warn "VPS: not reachable (check internet connection or VPS status)"
fi

echo ""
echo "===== DONE ====="
echo ""
echo "FAIL = needs action now"
echo "WARN = optional or may self-resolve after full restart"
echo ""
