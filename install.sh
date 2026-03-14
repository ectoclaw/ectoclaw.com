#!/usr/bin/env sh
# EctoClaw installer
# Usage: curl -sSL ectoclaw.com/install.sh | sh
#
# Wrapping everything in main() ensures the script is a no-op if the download
# is interrupted mid-transfer — a partial script will never execute.

set -eu

REPO="ectoclaw/ectoclaw"
BIN="ectoclaw"
INSTALL_DIR="/usr/local/bin"

# ── Colours (disabled if not a terminal) ─────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

info()    { printf "${BOLD}%s${RESET}\n" "$*"; }
success() { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}!${RESET} %s\n" "$*"; }
die()     { printf "${RED}error:${RESET} %s\n" "$*" >&2; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────
need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"
}

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "curl or wget is required"
  fi
}

# Detect how to run commands as root.
elevate() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  else
    die "Root privileges required. Install sudo or doas, or run as root."
  fi
}

# ── OS / arch detection ───────────────────────────────────────────────────────
detect_os() {
  OS="$(uname -s)"
  case "$OS" in
    Linux)  OS="Linux" ;;
    Darwin) OS="Darwin" ;;
    *)      die "Unsupported OS: $OS" ;;
  esac
}

detect_arch() {
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64)  ARCH="x86_64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *)             die "Unsupported architecture: $ARCH" ;;
  esac
}

# ── Version resolution ────────────────────────────────────────────────────────
latest_version() {
  VERSION="$(fetch "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
  [ -n "$VERSION" ] || die "Could not determine latest version. Is the GitHub repo public?"
}

# ── Already installed? ────────────────────────────────────────────────────────
check_existing() {
  if command -v "$BIN" >/dev/null 2>&1; then
    CURRENT="$("$BIN" version 2>/dev/null | head -1 || true)"
    warn "$BIN is already installed: ${CURRENT:-unknown version}"
    warn "Continuing will upgrade to $VERSION"
    printf "Proceed? [y/N] "
    # Skip prompt when piped (non-interactive).
    if [ -t 0 ]; then
      read -r answer
      case "$answer" in
        [yY]*) ;;
        *) info "Aborted."; exit 0 ;;
      esac
    else
      printf "non-interactive mode, proceeding\n"
    fi
  fi
}

# ── Download & install ────────────────────────────────────────────────────────
download_and_install() {
  TARBALL="${BIN}_${OS}_${ARCH}.tar.gz"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${TARBALL}"

  info "Downloading ${BIN} ${VERSION} (${OS}/${ARCH})..."

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  fetch "$DOWNLOAD_URL" | tar xz -C "$TMP"

  [ -f "$TMP/$BIN" ] || die "Binary not found in archive"

  chmod +x "$TMP/$BIN"
  elevate mv "$TMP/$BIN" "$INSTALL_DIR/$BIN"
}

# ── Verify ────────────────────────────────────────────────────────────────────
verify() {
  command -v "$BIN" >/dev/null 2>&1 || die "Installation failed: $BIN not found in PATH"
  INSTALLED="$("$BIN" version 2>/dev/null | head -1 || true)"
  success "Installed: ${INSTALLED:-$BIN $VERSION}"
}

# ── Next steps ────────────────────────────────────────────────────────────────
next_steps() {
  printf "\n"
  info "Next steps:"
  printf "  1. Initialise config and workspace:\n"
  printf "     ${BOLD}%s onboard${RESET}\n\n" "$BIN"
  printf "  2. Install as a background service:\n"
  printf "     ${BOLD}sudo %s service install${RESET}\n" "$BIN"
  printf "     ${BOLD}sudo %s service start${RESET}\n\n" "$BIN"
  printf "  Docs: https://github.com/${REPO}#readme\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  detect_os
  detect_arch
  latest_version
  check_existing
  download_and_install
  verify
  next_steps
}

main
