#!/usr/bin/env bash
# Bootstrap de máquina nueva (o re-instalación). Ejecutar UNA vez por equipo.
# A partir de ahí, sync.sh mantiene la máquina al día en cada arranque de sesión.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.claude"

chmod +x "$DIR/sync.sh"

# El propio sync hace todo el trabajo: trae origin/main, materializa el contrato
# aprobado y aplica la política (que incluye el hook de SessionStart).
"$DIR/sync.sh" > /dev/null

echo "OK — configuración aprobada aplicada desde $DIR"
echo "Contrato: $HOME/.claude/CLAUDE.md (copia gestionada; se edita por PR, no a mano)"
echo "La próxima sesión de Claude Code ya arranca con el contrato y el sync automático."
