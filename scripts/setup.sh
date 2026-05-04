#!/bin/bash
# ============================================================================
# Rico's Hermes Setup — All-in-One Installer
# ============================================================================
# Installs both Hermes Agent (from Rico's fork) and the Hermes WebUI in one go.
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/Rico0319/hermes-rico/main/scripts/setup.sh | bash
#
# Usage (file):
#   bash setup.sh
#   bash setup.sh --skip-setup     # Skip the interactive hermes setup wizard
#   bash setup.sh --webui-dir PATH # Use a custom WebUI install directory
#
# What this does:
#   1. Checks if Hermes Agent is already installed
#   2. If not, runs the Hermes Agent installer (interactive prompts work)
#   3. Clones (or updates) the Hermes WebUI
#   4. Bootstraps the WebUI (venv, dependencies, start)
# ============================================================================

set -e

# ── Colors ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ── Configuration ────────────────────────────────────────────────────────
AGENT_INSTALL_URL="https://raw.githubusercontent.com/Rico0319/hermes-rico/main/scripts/install.sh"
WEBUI_REPO="https://github.com/Rico0319/hermes-webui-rico.git"
WEBUI_DIR="${HOME}/hermes-webui"
RUN_SETUP=true
AGENT_INSTALL_DIR="${HERMES_INSTALL_DIR:-}"

# ── Helpers ──────────────────────────────────────────────────────────────
log_info()  { echo -e "${CYAN}→${NC} $1"; }
log_ok()    { echo -e "${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
log_err()   { echo -e "${RED}✗${NC} $1"; }
log_step()  { echo -e "\n${MAGENTA}${BOLD}━━━ $1 ━━━${NC}\n"; }

# ── Parse arguments ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-setup)
            RUN_SETUP=false
            shift
            ;;
        --webui-dir)
            WEBUI_DIR="$2"
            shift 2
            ;;
        --agent-dir)
            AGENT_INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo ""
            echo "Rico's Hermes Setup — All-in-One Installer"
            echo ""
            echo "Usage: setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-setup         Skip the interactive 'hermes setup' wizard at the end"
            echo "  --webui-dir PATH     Install WebUI to a custom directory (default: ~/hermes-webui)"
            echo "  --agent-dir PATH     Pass custom install dir to the Hermes Agent installer"
            echo "  -h, --help           Show this help"
            echo ""
            echo "One-liner (installs everything):"
            echo "  curl -fsSL https://raw.githubusercontent.com/Rico0319/hermes-rico/main/scripts/setup.sh | bash"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ── Check if agent is already installed ──────────────────────────────────
agent_already_installed() {
    if command -v hermes &>/dev/null; then
        return 0
    fi
    local agent_dirs=(
        "${HOME}/.hermes/hermes-agent"
        "/usr/local/lib/hermes-agent"
        "${HOME}/hermes-agent"
    )
    for d in "${agent_dirs[@]}"; do
        if [ -f "$d/run_agent.py" ]; then
            return 0
        fi
    done
    return 1
}

# ── Banner ───────────────────────────────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}"
echo "┌──────────────────────────────────────────────────────────┐"
echo "│        ⚕ Rico's Hermes — All-in-One Setup                │"
echo "├──────────────────────────────────────────────────────────┤"
echo "│  Hermes Agent  → github.com/Rico0319/hermes-rico          │"
echo "│  Hermes WebUI  → github.com/Rico0319/hermes-webui-rico    │"
echo "└──────────────────────────────────────────────────────────┘"
echo -e "${NC}"

# ── Step 1: Install Hermes Agent ────────────────────────────────────────
log_step "Step 1/2: Hermes Agent"

if agent_already_installed; then
    log_ok "Hermes Agent is already installed"
    if command -v hermes &>/dev/null; then
        log_info "  hermes command: $(command -v hermes)"
    fi
else
    log_info "Hermes Agent not found. Installing..."
    echo ""
    log_info "The Hermes installer will now run. It may ask you questions"
    log_info "about installing optional system packages (ripgrep, ffmpeg)."
    log_info "You can safely accept the defaults."
    echo ""

    # Download the installer to a temp file so bash can run it properly.
    # This is important: when this script is piped from curl, the inner
    # bash process inherits the pipe as stdin, but the Hermes install.sh
    # reads interactive prompts from /dev/tty — so prompts still work.
    TMP_INSTALL=$(mktemp /tmp/hermes-install.XXXXXX.sh)
    trap "rm -f '$TMP_INSTALL'" EXIT

    if ! curl -fsSL "$AGENT_INSTALL_URL" -o "$TMP_INSTALL"; then
        log_err "Failed to download Hermes installer from:"
        log_err "  $AGENT_INSTALL_URL"
        exit 1
    fi

    log_info "Running Hermes Agent installer..."
    # Build installer args
    INSTALL_ARGS=()
    [ "$RUN_SETUP" = false ] && INSTALL_ARGS+=("--skip-setup")
    [ -n "$AGENT_INSTALL_DIR" ] && INSTALL_ARGS+=("--dir" "$AGENT_INSTALL_DIR")

    if ! bash "$TMP_INSTALL" "${INSTALL_ARGS[@]}"; then
        log_err "Hermes Agent installation failed."
        log_info "You can try installing manually:"
        log_info "  curl -fsSL $AGENT_INSTALL_URL | bash"
        exit 1
    fi

    log_ok "Hermes Agent installed successfully"

    # Ensure ~/.local/bin is on PATH for this session
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# ── Step 2: Install WebUI ──────────────────────────────────────────────
log_step "Step 2/2: Hermes WebUI"

if [ -d "$WEBUI_DIR/.git" ]; then
    log_info "WebUI already exists at $WEBUI_DIR, updating..."
    cd "$WEBUI_DIR"
    if git pull --ff-only origin master 2>/dev/null; then
        log_ok "WebUI updated"
    else
        log_warn "Could not fast-forward update. Resetting to latest..."
        git fetch origin master
        git reset --hard origin/master
        log_ok "WebUI reset to latest"
    fi
else
    if [ -d "$WEBUI_DIR" ]; then
        log_warn "$WEBUI_DIR exists but is not a git repository"
        log_info "Backing up to ${WEBUI_DIR}.bak and re-cloning..."
        mv "$WEBUI_DIR" "${WEBUI_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
    fi
    log_info "Cloning WebUI from $WEBUI_REPO..."
    if ! git clone "$WEBUI_REPO" "$WEBUI_DIR"; then
        log_err "Failed to clone WebUI repository"
        exit 1
    fi
    log_ok "WebUI cloned to $WEBUI_DIR"
fi

cd "$WEBUI_DIR"

log_info "Bootstrapping WebUI..."
if ! python3 bootstrap.py; then
    log_err "WebUI bootstrap failed."
    log_info "Check that Hermes Agent is properly installed:"
    log_info "  hermes --version"
    log_info "Then re-run:"
    log_info "  cd $WEBUI_DIR && python3 bootstrap.py"
    exit 1
fi

# ── Done ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}┌──────────────────────────────────────────────────────────┐"
echo "│          ✓  Hermes setup complete!                       │"
echo "└──────────────────────────────────────────────────────────┘${NC}"
echo ""

# Check if hermes setup wizard was skipped (happens in pipe mode)
if command -v hermes &>/dev/null; then
    echo -e "  ${BOLD}Hermes Agent:${NC}  installed ($(hermes --version 2>/dev/null || echo 'ok'))"
else
    echo -e "  ${BOLD}Hermes Agent:${NC}  installed at ${HOME}/.hermes/hermes-agent"
fi

echo -e "  ${BOLD}WebUI:${NC}         installed at ${WEBUI_DIR}"
echo ""
echo -e "${BOLD}Quick start:${NC}"
echo "  cd ${WEBUI_DIR}"
echo "  python3 bootstrap.py"
echo ""

if [ "$RUN_SETUP" = true ]; then
    # Detect if we're in a pipe (setup wizard may have been skipped)
    if [ ! -t 0 ]; then
        echo -e "${YELLOW}Note:${NC} Running in pipe mode — the interactive setup wizard"
        echo "may have been skipped. Run this to configure your agent:"
        echo "  hermes setup"
        echo ""
    fi
fi

echo -e "${CYAN}Need help?${NC} https://github.com/Rico0319/hermes-rico"
echo ""
