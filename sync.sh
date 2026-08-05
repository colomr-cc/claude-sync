#!/usr/bin/env bash
# Orquestador de configuración global. Corre en cada SessionStart de Claude Code.
# Cualquier problema se comunica EN VOZ ALTA vía additionalContext del hook.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# Emite un mensaje por los DOS canales del protocolo de hooks:
#   - systemMessage      → se muestra en pantalla al usuario
#   - additionalContext  → entra en el contexto del modelo
# Ambos son necesarios: uno solo dejaría a ciegas a una de las dos partes.
# Solo informa: quien llama decide terminar (siempre con éxito, para no
# romper el arranque de la sesión por un problema de sincronización).
# El sync SIEMPRE habla: silencio sería indistinguible de "el hook no corrió".
say() {
  local msg="$1"
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg" "$msg"
  return 0
}

warn() {
  say "⚠️ claude-config: $1"
  return 0
}

# 1. El repo debe estar limpio y en main — si no, algo se hizo fuera del flujo
cd "$DIR" || { warn "no existe $DIR"; exit 0; }
if [[ -n "$(git status --porcelain)" ]]; then
  warn "repo SUCIO (cambios sin commitear) — el sync no actúa hasta resolverlo"
  exit 0
fi
BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" ]]; then
  warn "repo fuera de main (rama $BRANCH) — ¿PR a medias?"
  exit 0
fi

# 2. Traer la última política aprobada (sin red → seguimos con la local, avisando)
if ! git pull --ff-only -q 2>/dev/null; then
  warn "pull fallido (¿sin red?) — usando la última versión local"
  exit 0
fi

# 3. Fusionar política compartida → settings local (repo gana SOLO en sus claves)
if ! python3 "$DIR/merge_settings.py"; then
  warn "fusión de settings fallida — revisar JSON"
  exit 0
fi

# 4. Confirmar en voz alta qué contrato rige en esta máquina
CONTRATO="$(git log -1 --format='%h (%ad)' --date=short -- CLAUDE.md settings.shared.json)"
say "✅ claude-config sincronizado · contrato en vigor: ${CONTRATO}"
exit 0
