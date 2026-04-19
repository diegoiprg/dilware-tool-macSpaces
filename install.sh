#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# macSpaces — Instalador completo
# Resuelve todas las dependencias y deja el sistema listo.
# https://github.com/diegoiprg/dilware-tool-macGestorEntorno
# ─────────────────────────────────────────────────────────────
set -euo pipefail

REPO="diegoiprg/dilware-tool-macGestorEntorno"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
HS_DIR="${HOME}/.hammerspoon"

# ── Utilidades ───────────────────────────────────────────────

info()  { printf '→ %s\n' "$1"; }
ok()    { printf '✓ %s\n' "$1"; }
warn()  { printf '⚠ %s\n' "$1"; }
fail()  { printf '✗ %s\n' "$1"; exit 1; }

# ── 1. Xcode Command Line Tools ─────────────────────────────

if ! xcode-select -p &>/dev/null; then
  info "Instalando Xcode Command Line Tools (necesario para compilar)..."
  xcode-select --install 2>/dev/null || true
  # Esperar a que el usuario complete la instalación del diálogo del SO
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  ok "Xcode CLI Tools instalado"
else
  ok "Xcode CLI Tools disponible"
fi

# ── 2. Homebrew ──────────────────────────────────────────────

if ! command -v brew &>/dev/null; then
  info "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Agregar brew al PATH de esta sesión (Apple Silicon vs Intel)
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  ok "Homebrew instalado"
else
  ok "Homebrew disponible"
fi

# ── 3. Hammerspoon ───────────────────────────────────────────

if ! brew list --cask hammerspoon &>/dev/null; then
  info "Instalando Hammerspoon via Homebrew..."
  brew install --cask hammerspoon
  ok "Hammerspoon instalado"
else
  ok "Hammerspoon disponible"
fi

# Crear directorio de configuración si no existe
mkdir -p "${HS_DIR}"

# ── 4. Descargar archivos del repositorio ────────────────────

# Lista de archivos a descargar (relativa a la raíz del repo)
FILES=(
  init.lua
  macspaces/config.lua
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
  macspaces/focus_overlay.lua
  macspaces/focus_menu.lua
  macspaces/menu.lua
)

# Respaldar configuración existente
if [[ -f "${HS_DIR}/init.lua" ]]; then
  cp "${HS_DIR}/init.lua" "${HS_DIR}/init.lua.bak"
  info "Respaldo: init.lua.bak"
fi
if [[ -d "${HS_DIR}/macspaces" ]]; then
  # Preservar config.lua del usuario si existe
  if [[ -f "${HS_DIR}/macspaces/config.lua" ]]; then
    cp "${HS_DIR}/macspaces/config.lua" "${HS_DIR}/macspaces/config.lua.user"
    info "Respaldo de tu config: config.lua.user"
  fi
fi

mkdir -p "${HS_DIR}/macspaces"

info "Descargando archivos..."
for file in "${FILES[@]}"; do
  curl -fsSL "${BASE_URL}/${file}" -o "${HS_DIR}/${file}"
done
ok "Archivos descargados en ~/.hammerspoon/"

# Restaurar config del usuario si tenía una personalizada
if [[ -f "${HS_DIR}/macspaces/config.lua.user" ]]; then
  mv "${HS_DIR}/macspaces/config.lua.user" "${HS_DIR}/macspaces/config.lua"
  ok "Tu config.lua personalizado fue preservado"
fi

# ── 5. Compilar helper Swift (cambio de navegador) ──────────

info "Compilando set_browser..."
if swiftc "${HS_DIR}/macspaces/set_browser.swift" -o "${HS_DIR}/set_browser" 2>/dev/null; then
  ok "set_browser compilado"
else
  warn "No se pudo compilar set_browser — el cambio de navegador no funcionará"
fi

# ── 6. Permisos ──────────────────────────────────────────────

echo ""
echo "╭──────────────────────────────────────────────────╮"
echo "│  PERMISOS REQUERIDOS                             │"
echo "│                                                  │"
echo "│  macOS te pedirá permisos la primera vez que     │"
echo "│  abras Hammerspoon. Debes habilitarlos en:       │"
echo "│                                                  │"
echo "│  Ajustes del Sistema → Privacidad y Seguridad    │"
echo "│    → Accesibilidad → Hammerspoon ✓               │"
echo "│    → Automatización → Hammerspoon ✓              │"
echo "╰──────────────────────────────────────────────────╯"
echo ""

# ── 7. Lanzar Hammerspoon ────────────────────────────────────

if pgrep -xq "Hammerspoon"; then
  info "Recargando Hammerspoon..."
  # hs CLI puede no estar instalado; usar AppleScript como fallback
  if command -v hs &>/dev/null; then
    hs -c "hs.reload()" 2>/dev/null || true
  else
    osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' 2>/dev/null || true
  fi
  ok "Hammerspoon recargado"
else
  info "Abriendo Hammerspoon..."
  open -a Hammerspoon
  ok "Hammerspoon iniciado — acepta los permisos cuando aparezcan"
fi

echo ""
ok "macSpaces instalado. El ícono ⌘ aparecerá en tu barra de menú."
