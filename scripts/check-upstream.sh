#!/bin/bash
# ============================================================================
# check-upstream.sh — Personal upstream review helper for Rico's Fork
# ============================================================================
# Run this on your development machine to see what upstream has published
# that you haven't merged into your fork yet.
#
# Usage:
#   ./scripts/check-upstream.sh
#   ./scripts/check-upstream.sh --diff    # Show full diff preview
#   ./scripts/check-upstream.sh --log     # Show detailed commit log
#   ./scripts/check-upstream.sh --merge   # Interactive merge workflow
# ============================================================================

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

log_info() { echo -e "${CYAN}→${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Check that upstream remote exists
if ! git remote | grep -q "^upstream$"; then
    log_error "No 'upstream' remote found."
    log_info "Add it with: git remote add upstream https://github.com/NousResearch/hermes-agent.git"
    exit 1
fi

# Fetch latest upstream (quietly)
log_info "Fetching upstream..."
git fetch upstream --quiet

# Get current branch and commit info
CURRENT_BRANCH=$(git branch --show-current)
UPSTREAM_HEAD=$(git rev-parse --short upstream/main)
LOCAL_HEAD=$(git rev-parse --short main)
UPSTREAM_DATE=$(git log -1 --format=%ci upstream/main)
LOCAL_DATE=$(git log -1 --format=%ci main)

# Count commits ahead/behind
AHEAD=$(git rev-list --count main..upstream/main)
BEHIND=$(git rev-list --count upstream/main..main)

echo ""
echo -e "${BOLD}Upstream Sync Status${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Your fork (main):     ${GREEN}${LOCAL_HEAD}${NC}  (${LOCAL_DATE})"
echo -e "Upstream (main):      ${YELLOW}${UPSTREAM_HEAD}${NC}  (${UPSTREAM_DATE})"
echo ""

if [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -eq 0 ]; then
    log_success "Your fork is in sync with upstream. Nothing to review."
    exit 0
fi

if [ "$BEHIND" -gt 0 ]; then
    echo -e "Your fork is ${GREEN}${BEHIND} commit(s) ahead${NC} of upstream"
fi

if [ "$AHEAD" -eq 0 ]; then
    echo -e "Upstream has ${GREEN}no new commits${NC} since your last merge."
    exit 0
fi

echo -e "Upstream has ${YELLOW}${AHEAD} new commit(s)${NC} not in your fork:"
echo ""

# Parse arguments
MODE="summary"
if [ $# -gt 0 ]; then
    case "$1" in
        --diff)  MODE="diff" ;;
        --log)   MODE="log" ;;
        --merge) MODE="merge" ;;
        *)
            echo "Usage: $0 [--diff|--log|--merge]"
            exit 1
            ;;
    esac
fi

case "$MODE" in
    summary)
        git log --oneline --reverse main..upstream/main
        echo ""
        log_info "Run '$0 --diff' to preview changes"
        log_info "Run '$0 --log' for detailed commit info"
        log_info "Run '$0 --merge' to start the merge workflow"
        ;;

    diff)
        log_info "Previewing diff (first 200 lines)..."
        echo ""
        git diff main..upstream/main | head -200
        echo ""
        log_info "End of preview. Full diff: git diff main..upstream/main"
        ;;

    log)
        git log --format="%h | %ad | %s | %an" --date=short --reverse main..upstream/main
        echo ""
        ;;

    merge)
        echo ""
        echo -e "${BOLD}Merge Workflow${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "You are about to merge upstream changes into your fork."
        echo "Your users will receive these changes when they run 'hermes update'."
        echo ""
        read -r -p "Continue with merge? [y/N] " CONFIRM
        case "$CONFIRM" in
            [yY]|[yY][eE][sS])
                echo ""
                log_info "Checking out main..."
                git checkout main
                
                log_info "Merging upstream/main..."
                if git merge upstream/main --no-ff -m "Merge upstream: sync ${UPSTREAM_HEAD} into fork"; then
                    log_success "Merge successful!"
                    echo ""
                    log_info "Test the changes before pushing:"
                    echo "  cd ${REPO_DIR}"
                    echo "  source .venv/bin/activate"
                    echo "  python -m pytest tests/ -q"
                    echo ""
                    read -r -p "Push to your fork now? [y/N] " PUSH
                    case "$PUSH" in
                        [yY]|[yY][eE][sS])
                            git push origin main
                            log_success "Pushed! Users can now 'hermes update' to receive these changes."
                            ;;
                        *)
                            log_warn "Not pushed. Push manually when ready:"
                            log_info "  git push origin main"
                            ;;
                    esac
                else
                    log_error "Merge failed. Resolve conflicts and try again."
                    log_info "  git status"
                    log_info "  git mergetool"
                    log_info "  git merge --abort  (to cancel)"
                    exit 1
                fi
                ;;
            *)
                log_info "Merge cancelled."
                exit 0
                ;;
        esac
        ;;
esac

echo ""
