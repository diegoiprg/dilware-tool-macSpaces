#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# macSpaces — Instalador
# Modo dual: symlinks (repo local) o descarga (curl | bash).
# Uso: bash install.sh [--dry-run]
# ─────────────────────────────────────────────────────────────
set -euo pipefail

GITHUB_REPO="diegoiprg/dilware-tool-macGestorEntorno"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${BRANCH}"
HS_DIR="${HOME}/.hammerspoon"
DRY=false
MODE=""  # "local" o "remote"

for arg in "$@"; do
  case $arg in
    --dry-run) DRY=true ;;
  esac
done

# ── Detección de modo ────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

if [[ -n "${SCRIPT_DIR:-}" ]] && [[ -d "${SCRIPT_DIR}/.git" ]] && [[ -f "${SCRIPT_DIR}/init.lua" ]]; then
  MODE="local"
  REPO="$SCRIPT_DIR"
else
  MODE="remote"
fi

# ── Colores y helpers ────────────────────────────────────────

GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'

info() { echo -e "  ${DIM}→${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; exit 1; }
section() { echo ""; echo -e "${BOLD}$1${RESET}"; }

# Estado por sección para resumen final
S_XCODE="" ; S_BREW="" ; S_HAMMER="" ; S_FILES="" ; S_SWIFT="" ; S_LAUNCH=""

# ── Archivos del proyecto ────────────────────────────────────

FILES=(
  init.lua
  macspaces/config.lua
  macspaces/version.lua
  macspaces/utils.lua
  macspaces/profiles.lua
  macspaces/browsers.lua
  macspaces/set_browser.swift
  macspaces/audio.lua
  macspaces/music.lua
  macspaces/battery.lua
  macspaces/bluetooth.lua
  macspaces/network.lua
  macspaces/vpn.lua
  macspaces/clipboard.lua
  macspaces/pomodoro.lua
  macspaces/breaks.lua
  macspaces/presentation.lua
  macspaces/launcher.lua
  macspaces/history.lua
  macspaces/hotkeys.lua
  macspaces/dnd.lua
  macspaces/claude.lua
  macspaces/gemini.lua
  macspaces/focus_overlay.lua
  macspaces/focus_menu.lua
  macspaces/menu.lua
)

# ── Migración de config.lua del usuario ──────────────────────

migrate_config_version() {
  local cfg="${HS_DIR}/macspaces/config.lua"
  [[ -f "$cfg" ]] || return 0
  if grep -q 'M\.VERSION *= *"' "$cfg" 2>/dev/null; then
    $DRY && { info "se migraría VERSION en config.lua"; return 0; }
    sed -i '' 's/M\.VERSION *= *"[^"]*"/M.VERSION = require("macspaces.version")/' "$cfg"
    ok "config.lua: VERSION migrada a require(\"macspaces.version\")"
  fi
}

# ── Funciones de instalación de archivos ─────────────────────

LINK_COUNT=0

install_local() {
  # Preservar config.lua del usuario si no es symlink
  local has_user_config=false
  if [[ -f "${HS_DIR}/macspaces/config.lua" ]] && [[ ! -L "${HS_DIR}/macspaces/config.lua" ]]; then
    has_user_config=true
    $DRY || cp "${HS_DIR}/macspaces/config.lua" "${HS_DIR}/macspaces/config.lua.user"
  fi

  mkdir -p "${HS_DIR}/macspaces"

  for file in "${FILES[@]}"; do
    local dst="${HS_DIR}/${file}"
    local src="${REPO}/${file}"
    if [[ ! -e "$src" ]]; then
      warn "No existe: $file"
      continue
    fi
    if $DRY; then
      LINK_COUNT=$((LINK_COUNT + 1))
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    # Si existe y no es symlink, respaldar
    [[ -e "$dst" ]] && [[ ! -L "$dst" ]] && mv "$dst" "${dst}.bak"
    ln -sf "$src" "$dst"
    LINK_COUNT=$((LINK_COUNT + 1))
  done

  # Restaurar config del usuario
  if $has_user_config; then
    if ! $DRY; then
      rm -f "${HS_DIR}/macspaces/config.lua"
      mv "${HS_DIR}/macspaces/config.lua.user" "${HS_DIR}/macspaces/config.lua"
    fi
    ok "config.lua personalizado preservado"
    migrate_config_version
  fi

  ok "${LINK_COUNT} symlinks → ~/.hammerspoon/"
  S_FILES="ok:${LINK_COUNT} symlinks"
}

install_remote() {
  # Preservar config.lua del usuario
  if [[ -f "${HS_DIR}/macspaces/config.lua" ]]; then
    cp "${HS_DIR}/macspaces/config.lua" "${HS_DIR}/macspaces/config.lua.user"
  fi

  mkdir -p "${HS_DIR}/macspaces"

  local count=0
  for file in "${FILES[@]}"; do
    if $DRY; then
      count=$((count + 1))
      continue
    fi
    curl -fsSL "${BASE_URL}/${file}" -o "${HS_DIR}/${file}"
    count=$((count + 1))
  done

  # Restaurar config del usuario
  if [[ -f "${HS_DIR}/macspaces/config.lua.user" ]]; then
    if ! $DRY; then
      mv "${HS_DIR}/macspaces/config.lua.user" "${HS_DIR}/macspaces/config.lua"
    fi
    ok "config.lua personalizado preservado"
    migrate_config_version
  fi

  ok "${count} archivos descargados → ~/.hammerspoon/"
  S_FILES="ok:${count} archivos descargados"
}

# ── Banner ───────────────────────────────────────────────────

echo ""
echo -e "${BOLD}macSpaces${RESET} — instalador"
if [[ "$MODE" == "local" ]]; then
  echo -e "  ${DIM}modo local — symlinks desde ${REPO}${RESET}"
else
  echo -e "  ${DIM}modo remoto — descarga desde GitHub${RESET}"
fi
$DRY && echo -e "  ${YELLOW}dry-run — no se aplica ningún cambio${RESET}"

# ── 1. Xcode CLI Tools ──────────────────────────────────────

section "Xcode CLI Tools"

if xcode-select -p &>/dev/null; then
  ok "disponible"
  S_XCODE="ok:disponible"
else
  if $DRY; then
    info "se instalaría"
    S_XCODE="ok:dry-run"
  else
    info "instalando (aparecerá un diálogo del sistema)..."
    xcode-select --install 2>/dev/null || true
    until xcode-select -p &>/dev/null; do sleep 5; done
    ok "instalado"
    S_XCODE="ok:instalado"
  fi
fi

# ── 2. Homebrew ──────────────────────────────────────────────

section "Homebrew"

if command -v brew &>/dev/null; then
  ok "disponible"
  S_BREW="ok:disponible"
else
  if $DRY; then
    info "se instalaría"
    S_BREW="ok:dry-run"
  else
    info "instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ok "instalado"
    S_BREW="ok:instalado"
  fi
fi

# ── 3. Hammerspoon ───────────────────────────────────────────

section "Hammerspoon"

if brew list --cask hammerspoon &>/dev/null 2>&1 || [[ -d "/Applications/Hammerspoon.app" ]]; then
  ok "disponible"
  S_HAMMER="ok:disponible"
else
  if $DRY; then
    info "se instalaría"
    S_HAMMER="ok:dry-run"
  else
    info "instalando..."
    brew install --cask hammerspoon
    ok "instalado"
    S_HAMMER="ok:instalado"
  fi
fi

# ── 4. Archivos ──────────────────────────────────────────────

section "Archivos"

if [[ "$MODE" == "local" ]]; then
  install_local
else
  install_remote
fi

# ── 5. Compilar helper Swift ─────────────────────────────────

section "Helper Swift"

SWIFT_SRC="${HS_DIR}/macspaces/set_browser.swift"
SWIFT_BIN="${HS_DIR}/set_browser"

if $DRY; then
  info "se compilaría set_browser"
  S_SWIFT="ok:dry-run"
else
  # En modo local, el source es un symlink — resolver para swiftc
  local_src="$SWIFT_SRC"
  [[ -L "$SWIFT_SRC" ]] && local_src="$(readlink "$SWIFT_SRC")"

  if swiftc "$local_src" -o "$SWIFT_BIN" 2>/dev/null; then
    ok "set_browser compilado"
    S_SWIFT="ok:compilado"
  else
    warn "no se pudo compilar — el cambio de navegador no funcionará"
    S_SWIFT="warn:falló compilación"
  fi
fi

# ── 6. Lanzar Hammerspoon ───────────────────────────────────

section "Hammerspoon"

if $DRY; then
  info "se lanzaría/recargaría"
  S_LAUNCH="ok:dry-run"
elif pgrep -xq "Hammerspoon"; then
  if command -v hs &>/dev/null; then
    hs -c "hs.reload()" 2>/dev/null || true
  else
    osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' 2>/dev/null || true
  fi
  ok "recargado"
  S_LAUNCH="ok:recargado"
else
  open -a Hammerspoon
  ok "iniciado"
  S_LAUNCH="ok:iniciado"
fi

# ── Resumen ──────────────────────────────────────────────────

summary_line() {
  local label="$1" state="$2"
  local status="${state%%:*}" detail="${state#*:}"
  local pad
  pad=$(printf '%*s' $((14 - ${#label})) '')
  case "$status" in
    ok)   echo -e "  ${GREEN}✓${RESET}  ${label}${pad}${DIM}${detail}${RESET}" ;;
    warn) echo -e "  ${YELLOW}⚠${RESET}  ${label}${pad}${YELLOW}${detail}${RESET}" ;;
    fail) echo -e "  ${RED}✗${RESET}  ${label}${pad}${RED}${detail}${RESET}" ;;
  esac
}

echo ""
echo -e "${DIM}─────────────────────────────────────────────────${RESET}"
summary_line "Xcode CLI"    "$S_XCODE"
summary_line "Homebrew"     "$S_BREW"
summary_line "Hammerspoon"  "$S_HAMMER"
summary_line "Archivos"     "$S_FILES"
summary_line "Swift helper" "$S_SWIFT"
summary_line "Lanzamiento"  "$S_LAUNCH"
echo -e "${DIM}─────────────────────────────────────────────────${RESET}"

# Permisos — solo mostrar si es primera instalación
if [[ "${S_HAMMER}" == *"instalado"* ]]; then
  echo ""
  echo -e "  ${BOLD}Permisos requeridos:${RESET}"
  echo -e "  Ajustes del Sistema → Privacidad y Seguridad"
  echo -e "    → Accesibilidad → Hammerspoon ✓"
  echo -e "    → Automatización → Hammerspoon ✓"
fi

echo ""
