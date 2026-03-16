#!/usr/bin/env bash
# Instalador de macSpaces (dilware-tool-macSpaces)
# https://github.com/diegoiprg/dilware-tool-macSpaces

set -euo pipefail

REPO_URL="https://github.com/diegoiprg/dilware-tool-macSpaces.git"
REPO_DIR="${HOME}/dilware-tool-macSpaces"
HS_DIR="${HOME}/.hammerspoon"
INIT_FILE="init.lua"

echo "◇ Instalando macSpaces..."

# Verificar dependencia: git
if ! command -v git &>/dev/null; then
  echo "✗ git no está instalado. Instálalo con: xcode-select --install"
  exit 1
fi

# Verificar que Hammerspoon haya sido ejecutado al menos una vez
if [ ! -d "${HS_DIR}" ]; then
  echo "✗ No se encontró ~/.hammerspoon"
  echo "  Instala Hammerspoon desde https://www.hammerspoon.org y ábrelo al menos una vez."
  exit 1
fi

# Clonar o actualizar el repositorio
if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "→ Clonando repositorio..."
  git clone "${REPO_URL}" "${REPO_DIR}"
else
  echo "→ Actualizando repositorio..."
  # Verificar conectividad antes de intentar pull
  if git -C "${REPO_DIR}" fetch --dry-run 2>/dev/null; then
    git -C "${REPO_DIR}" pull --ff-only
  else
    echo "  (sin acceso a red, usando versión local)"
  fi
fi

# Respaldar configuración existente si la hay
if [ -f "${HS_DIR}/${INIT_FILE}" ]; then
  BACKUP="${HS_DIR}/${INIT_FILE}.bak"
  cp "${HS_DIR}/${INIT_FILE}" "${BACKUP}"
  echo "→ Respaldo guardado en ${BACKUP}"
fi

# Copiar configuración
echo "→ Copiando ${INIT_FILE} a ${HS_DIR}..."
cp "${REPO_DIR}/${INIT_FILE}" "${HS_DIR}/${INIT_FILE}"

echo "✓ Instalación completa."
echo "  Abre Hammerspoon y presiona ⌘R para recargar."
