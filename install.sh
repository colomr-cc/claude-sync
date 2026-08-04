#!/usr/bin/env bash
# Bootstrap de máquina nueva (o re-instalación). Ejecutar UNA vez por equipo.
# Regla: ante conflicto, el repo GANA en lo que gestiona; lo local no gestionado se conserva.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.claude"

# Contrato: symlink — una sola fuente de verdad, actualizada vía git
ln -sf "$DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Política: primera fusión + registro del hook de SessionStart (viene en settings.shared.json)
python3 "$DIR/merge_settings.py"

chmod +x "$DIR/sync.sh"
echo "OK — contrato enlazado y política sincronizada desde $DIR"
echo "La próxima sesión de Claude Code ya arranca con el contrato y el sync automático."
