#!/bin/bash
# ============================================================================
# Hermes for Living Style — All-in-One Setup
# ============================================================================
# Installs both Hermes Agent and the Hermes WebUI in one go.
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/Rico0319/hermes-rico/main/scripts/setup.sh | bash
#
# Usage (file):
#   bash setup.sh
#   bash setup.sh --webui-dir PATH  # Use a custom WebUI install directory
#
# What this does:
#   1. Checks if Hermes Agent is already installed
#   2. If not, runs the Hermes Agent installer (auto-answers yes to packages)
#   3. Clones (or updates) the Hermes WebUI
#   4. Bootstraps the WebUI (venv, dependencies, launch)
#   5. Creates a desktop shortcut for easy access
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
            echo "Hermes for Living Style — All-in-One Setup"
            echo ""
            echo "Usage: setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --webui-dir PATH    Install WebUI to a custom directory (default: ~/hermes-webui)"
            echo "  --agent-dir PATH    Pass custom install dir to the Hermes Agent installer"
            echo "  -h, --help          Show this help"
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

# ── OS detection ─────────────────────────────────────────────────────────
OS="linux"
case "$(uname -s)" in
    Darwin*) OS="macos" ;;
esac

# ── Homebrew check (macOS only) ───────────────────────────────────────────
# Homebrew is required on macOS for installing ripgrep, ffmpeg, and other
# optional dependencies. We auto-install it so non-technical users don't
# get stuck. The only interaction needed is a possible macOS password prompt.
ensure_homebrew() {
    if [ "$OS" != "macos" ]; then
        return 0
    fi

    # Already installed? Nothing to do.
    if command -v brew &>/dev/null; then
        log_ok "Homebrew already installed ($(brew --version | head -1))"
        return 0
    fi

    log_step "Installing Homebrew (macOS package manager)"
    log_info "Homebrew is required for installing system dependencies."
    log_info "You may be asked to type your macOS password once."

    # The official Homebrew install script runs non-interactively when piped to bash.
    # It may prompt for sudo password via the terminal — that's expected and fine.
    # It also installs Xcode Command Line Tools if missing (may show a GUI popup).
    local brew_result
    brew_result=0

    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty; then
        brew_result=0
    else
        brew_result=1
    fi

    if [ "$brew_result" -ne 0 ]; then
        echo ""
        log_err "Homebrew installation failed."
        log_err "This script requires Homebrew to install necessary components."
        log_err ""
        log_err "You can install Homebrew manually:"
        log_err "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        log_err "Then re-run this setup script."
        echo ""
        exit 1
    fi

    # On Apple Silicon Macs, Homebrew installs to /opt/homebrew.
    # On Intel Macs, it installs to /usr/local.
    # We need to add it to PATH for this script session.
    for brew_path in "/opt/homebrew/bin" "/usr/local/bin"; do
        if [ -x "$brew_path/brew" ]; then
            export PATH="$brew_path:$PATH"
            log_ok "Homebrew installed successfully at $brew_path"
            break
        fi
    done

    if ! command -v brew &>/dev/null; then
        log_err "Homebrew was installed but the 'brew' command is not on PATH."
        log_err "This is unexpected. Please open a new terminal and re-run this script."
        exit 1
    fi

    log_ok "Homebrew is ready ($(brew --version | head -1))"
}

# ── Pre-install optional packages (so install.sh has nothing to ask) ─────
install_optional_packages() {
    log_info "Pre-installing optional system packages (ripgrep, ffmpeg)..."

    # ── macOS ──
    if [ "$OS" = "macos" ]; then
        brew install ripgrep ffmpeg 2>/dev/null && log_ok "ripgrep + ffmpeg installed via Homebrew"
        return
    fi

    # ── Linux: try passwordless sudo first, then passwordless, then skip ──
    local install_cmd=""
    local pkgs=""

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                pkgs="ripgrep ffmpeg"
                ;;
            fedora)
                pkgs="ripgrep ffmpeg-free"
                ;;
            arch)
                pkgs="ripgrep ffmpeg"
                ;;
        esac
    fi

    if [ -z "$pkgs" ]; then
        log_warn "Could not detect Linux distro — skipping optional packages"
        return
    fi

    # Try passwordless sudo
    if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        case "$ID" in
            ubuntu|debian) sudo DEBIAN_FRONTEND=noninteractive apt install -y $pkgs 2>/dev/null && log_ok "Packages installed ($pkgs)" || log_warn "Could not install packages" ;;
            fedora)        sudo dnf install -y $pkgs 2>/dev/null && log_ok "Packages installed ($pkgs)" || log_warn "Could not install packages" ;;
            arch)          sudo pacman -S --noconfirm $pkgs 2>/dev/null && log_ok "Packages installed ($pkgs)" || log_warn "Could not install packages" ;;
        esac
    else
        log_info "No passwordless sudo — packages will be skipped during Hermes install"
    fi
}

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

# ── Desktop shortcut ─────────────────────────────────────────────────────
create_desktop_shortcut() {
    local desktop_dir="${HOME}/Desktop"
    local start_script="${WEBUI_DIR}/start.sh"

    # If no Desktop dir (headless systems), try common alternatives
    if [ ! -d "$desktop_dir" ]; then
        # Try XDG desktop directory
        if command -v xdg-user-dir &>/dev/null; then
            desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo '')"
        fi
        if [ -z "$desktop_dir" ] || [ ! -d "$desktop_dir" ]; then
            log_warn "No Desktop directory found — skipping shortcut"
            return
        fi
    fi

    if [ "$OS" = "macos" ]; then
        # macOS: create a double-clickable .command file
        local shortcut="${desktop_dir}/Hermes WebUI.command"
        cat > "$shortcut" << EOF
#!/bin/bash
cd "${WEBUI_DIR}"
python3 bootstrap.py
EOF
        chmod +x "$shortcut"
        log_ok "Desktop shortcut created: ${desktop_dir}/Hermes WebUI.command"

    else
        # Linux: create a .desktop file
        local shortcut="${desktop_dir}/hermes-webui.desktop"
        cat > "$shortcut" << EOF
[Desktop Entry]
Type=Application
Name=Hermes WebUI
Comment=Launch Hermes AI Web Interface for Living Style
Exec=bash -c 'cd "${WEBUI_DIR}" && python3 bootstrap.py'
Icon=utilities-terminal
Terminal=true
Categories=Utility;
EOF
        chmod +x "$shortcut"
        log_ok "Desktop shortcut created: ${desktop_dir}/hermes-webui.desktop"
    fi
}

# ── Banner ───────────────────────────────────────────────────────────────
echo ""
echo -e "${MAGENTA}${BOLD}"
echo "┌──────────────────────────────────────────────────────────┐"
echo "│        ⚕  Hermes for Living Style — Setup                │"
echo "├──────────────────────────────────────────────────────────┤"
echo "│  Hermes Agent  → github.com/Rico0319/hermes-rico          │"
echo "│  Hermes WebUI  → github.com/Rico0319/hermes-webui-rico    │"
echo "└──────────────────────────────────────────────────────────┘"
echo -e "${NC}"

# ── Step 0 (macOS only): Ensure Homebrew is installed ────────────────────
# This must run BEFORE any package installations so ripgrep/ffmpeg
# can be installed via Homebrew without asking the user any questions.
ensure_homebrew

# ── Step 1: Pre-install optional packages ────────────────────────────────
# Run this BEFORE the agent installer so there are no interactive prompts
# about ripgrep/ffmpeg during the Hermes install.
install_optional_packages

# ── Step 2: Install Hermes Agent ────────────────────────────────────────
log_step "Step 1/2: Hermes Agent"

if agent_already_installed; then
    log_ok "Hermes Agent is already installed"
    if command -v hermes &>/dev/null; then
        log_info "  hermes command: $(command -v hermes)"
    fi
else
    log_info "Hermes Agent not found. Installing..."
    echo ""
    log_info "Installing Hermes Agent (this may take a few minutes)..."
    echo ""

    # Download the installer to a temp file.
    # We pass --skip-setup so the interactive 'hermes setup' wizard
    # (which asks about launching the CLI) is skipped entirely —
    # we go straight to WebUI setup instead.
    TMP_INSTALL=$(mktemp /tmp/hermes-install.XXXXXX.sh)
    trap "rm -f '$TMP_INSTALL'" EXIT

    if ! curl -fsSL "$AGENT_INSTALL_URL" -o "$TMP_INSTALL"; then
        log_err "Failed to download Hermes installer from:"
        log_err "  $AGENT_INSTALL_URL"
        exit 1
    fi

    log_info "Running Hermes Agent installer..."

    INSTALL_ARGS=("--skip-setup")
    [ -n "$AGENT_INSTALL_DIR" ] && INSTALL_ARGS+=("--dir" "$AGENT_INSTALL_DIR")

    # Automatically answer "yes" to any remaining prompts (e.g. sudo password
    # requests) by piping 'y' to the installer. Since we pre-installed
    # ripgrep/ffmpeg above, the main "install optional packages?" prompt
    # won't appear — but this fallback ensures no stalls.
    if yes | bash "$TMP_INSTALL" "${INSTALL_ARGS[@]}" 2>/dev/null; then
        log_ok "Hermes Agent installed successfully"
    else
        # If yes-pipe fails (e.g. on a sudo password prompt), retry without pipe
        log_warn "Auto-answer install failed — retrying interactively..."
        if ! bash "$TMP_INSTALL" "${INSTALL_ARGS[@]}"; then
            log_err "Hermes Agent installation failed."
            log_info "You can try installing manually:"
            log_info "  curl -fsSL $AGENT_INSTALL_URL | bash"
            exit 1
        fi
    fi

    # Ensure ~/.local/bin is on PATH for this session
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# ── Step 3: Install WebUI ──────────────────────────────────────────────
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

# ── Step 4: Create desktop shortcut ──────────────────────────────────────
create_desktop_shortcut

# ── Done ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}┌──────────────────────────────────────────────────────────┐"
echo "│          ✓  Hermes for Living Style — Setup complete!     │"
echo "└──────────────────────────────────────────────────────────┘${NC}"
echo ""

if command -v hermes &>/dev/null; then
    echo -e "  ${BOLD}Hermes Agent:${NC}  installed ($(hermes --version 2>/dev/null || echo 'ok'))"
else
    echo -e "  ${BOLD}Hermes Agent:${NC}  installed at ${HOME}/.hermes/hermes-agent"
fi

echo -e "  ${BOLD}WebUI:${NC}         installed at ${WEBUI_DIR}"
echo ""

echo -e "${BOLD}Quick start:${NC}"
echo "  Desktop:  Double-click the shortcut on your Desktop"
echo "  Terminal: cd ${WEBUI_DIR} && python3 bootstrap.py"
echo ""

echo -e "${CYAN}Need help?${NC} https://github.com/Rico0319/hermes-rico"
echo ""
