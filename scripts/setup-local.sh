#!/usr/bin/env bash
#
# SpeedType One-Command Setup
# ============================
#
# Paste this into your terminal (Mac / Linux / Windows WSL) to:
#   1. Install the Claude Code CLI (if not already installed)
#   2. Clone the SpeedType repo
#   3. Check out the development branch
#   4. Install Flutter deps (if Flutter is installed)
#   5. Launch Claude Code in the project directory
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/podbihis-sys/SpeedType/claude/cloud-storage-setup-RQZAO/scripts/setup-local.sh | bash
#
# Or manually:
#   chmod +x scripts/setup-local.sh && ./scripts/setup-local.sh

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}SpeedType local setup${NC}"
echo ""

# ---------------------------------------------------------------------------
# 1. Node.js check
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  echo -e "${RED}Node.js is required but not installed.${NC}"
  echo "Install from https://nodejs.org (LTS version) and re-run this script."
  exit 1
fi
echo -e "${GREEN}Node.js:${NC}       $(node --version)"

# ---------------------------------------------------------------------------
# 2. Claude Code CLI
# ---------------------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  echo -e "${YELLOW}Claude Code CLI not found. Installing...${NC}"
  npm install -g @anthropic-ai/claude-code
  echo -e "${GREEN}Claude Code installed.${NC}"
else
  echo -e "${GREEN}Claude Code:${NC}   $(claude --version 2>/dev/null | head -1)"
fi

# ---------------------------------------------------------------------------
# 3. Flutter check (optional but strongly recommended)
# ---------------------------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
  echo -e "${GREEN}Flutter:${NC}       $FLUTTER_VERSION"
  HAS_FLUTTER=1
else
  echo -e "${YELLOW}Flutter SDK not found.${NC}"
  echo "   Install from https://docs.flutter.dev/get-started/install"
  echo "   (you can continue without it - Claude will help you install it)"
  HAS_FLUTTER=0
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Clone the repo
# ---------------------------------------------------------------------------
REPO_DIR="SpeedType"

if [ -d "$REPO_DIR" ]; then
  echo -e "${BLUE}SpeedType folder already exists, pulling latest...${NC}"
  cd "$REPO_DIR"
  git fetch origin
  git checkout claude/cloud-storage-setup-RQZAO 2>/dev/null || \
    git checkout -b claude/cloud-storage-setup-RQZAO origin/claude/cloud-storage-setup-RQZAO
  git pull origin claude/cloud-storage-setup-RQZAO
else
  echo -e "${BLUE}Cloning repo...${NC}"
  git clone https://github.com/podbihis-sys/SpeedType.git
  cd "$REPO_DIR"
  git checkout claude/cloud-storage-setup-RQZAO
fi

echo -e "${GREEN}Repo ready at: $(pwd)${NC}"
echo ""

# ---------------------------------------------------------------------------
# 5. Flutter pub get (if Flutter is installed)
# ---------------------------------------------------------------------------
if [ "$HAS_FLUTTER" -eq 1 ]; then
  echo -e "${BLUE}Running flutter pub get...${NC}"
  flutter pub get || echo -e "${YELLOW}pub get had warnings - Claude will help fix them.${NC}"
  echo ""
fi

# ---------------------------------------------------------------------------
# 6. Final instructions
# ---------------------------------------------------------------------------
echo -e "${BOLD}${GREEN}Setup complete!${NC}"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo -e "  ${BLUE}1.${NC} Start Claude Code in this folder:"
echo "       claude"
echo ""
echo -e "  ${BLUE}2.${NC} In the Claude session, tell it:"
echo '       "Read HANDOVER.md and continue from where the cloud session left off"'
echo ""
echo -e "  ${BLUE}3.${NC} To preview the app (if Flutter is installed):"
echo "       flutter run -t lib/main_demo.dart -d chrome"
echo ""
echo -e "${YELLOW}First-time Claude login:${NC} a browser window will open, log in, return to terminal."
echo ""
echo -e "Ready? ${BOLD}Type:${NC} ${GREEN}claude${NC}"
