#!/bin/bash

# Dilware macSpaces Installer
# v2.12.2

set -e

# Config
REPO="https://github.com/diegoiprg/dilware-tool-macGestorEntorno"
DEST="$HOME/.hammerspoon"
LOG="$HOME/.hammerspoon/install.log"

echo "Instalando macSpaces v2.12.2..." | tee "$LOG"

# 1. Asegurar directorios
mkdir -p "$DEST"

# 2. Instalar gemini.lua
cp macspaces/gemini.lua "$DEST/gemini.lua"
echo "gemini.lua instalado." | tee -a "$LOG"

# 3. Finalizar
echo "Instalación completada. Reinicia Hammerspoon." | tee -a "$LOG"
