#!/usr/bin/env bash
# Orquestador de configuración global. Corre en cada SessionStart de Claude Code.
# Cualquier problema se comunica EN VOZ ALTA vía additionalContext del hook.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"

warn() {
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"⚠️ claude-config: %s"}}\n' "$1"
  exit 0
}

# 1. El repo debe estar limpio y en main — si no, algo se hizo fuera del flujo
cd "$DIR" || warn "no existe $DIR"
if [ -n "$(git status --porcelain)" ]; then
  warn "repo SUCIO (cambios sin commitear) — el sync no actúa hasta resolverlo"
fi
BRANCH="$(git branch --show-current)"
if [ "$BRANCH" != "main" ]; then
  warn "repo fuera de main (rama $BRANCH) — ¿PR a medias?"
fi

# 2. Traer la última política aprobada (sin red → seguimos con la local, avisando)
if ! git pull --ff-only -q 2>/dev/null; then
  warn "pull fallido (¿sin red?) — usando la última versión local"
fi

# 3. Fusionar política compartida → settings local (repo gana SOLO en sus claves)
if ! python3 "$DIR/merge_settings.py" "$DIR/settings.shared.json" "$SETTINGS"; then
  warn "fusión de settings fallida — revisar JSON"
fi

exit 0
