#!/usr/bin/env bash
# Materializa la configuración APROBADA (la de origin/main) en esta máquina.
# Corre en cada SessionStart de Claude Code.
#
# No depende del estado del árbol de trabajo: lee del historial con `git show`,
# así que da igual en qué rama estés o si tienes cambios sin commitear — lo que
# rige es siempre lo que se mergeó a main. Habla SIEMPRE, y por los dos canales
# (systemMessage para el usuario, additionalContext para el modelo).
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CONTRATO="$HOME/.claude/CLAUDE.md"
CACHE_STATE="$HOME/.claude/MANDATORY.cache"
REF="origin/main"

say() {
  local msg="$1"
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg" "$msg"
  return 0
}

extract_mandatory() {
  local file="$1"
  sed -n '/^## MANDATORY CHECKLIST$/,/^## [^M]/p' "$file" | head -n -1
}

cd "$DIR" || { say "⚠️ claude-sync: no existe $DIR — revisar la instalación"; exit 0; }

# 1. Traer la referencia aprobada. Sin red se sigue con la última conocida.
NOTA=""
if ! git fetch --quiet origin main 2>/dev/null; then
  NOTA=" · ⚠️ no access to origin: using last known reference"
else
  # Actualizar rama local main sin cambiar la rama actual
  git branch -f main origin/main 2>/dev/null
fi

if ! git rev-parse --verify --quiet "$REF" >/dev/null; then
  say "⚠️ claude-sync: reference $REF does not exist — check installation"
  exit 0
fi

# 2. Materializar el contrato aprobado si difiere del que hay en ~/.claude
ACTUAL=""
if [[ -f "$CONTRATO" ]]; then
  ACTUAL="$(git hash-object "$CONTRATO")"
fi
APROBADO="$(git rev-parse "$REF:CLAUDE.md" 2>/dev/null)"

CAMBIO=""
if [[ -z "$APROBADO" ]]; then
  say "⚠️ claude-sync: CLAUDE.md not found in $REF"
  exit 0
fi
if [[ "$ACTUAL" != "$APROBADO" ]]; then
  mkdir -p "$(dirname "$CONTRATO")"
  TMP="$(mktemp)"
  if ! git show "$REF:CLAUDE.md" > "$TMP"; then
    rm -f "$TMP"
    say "⚠️ claude-sync: failed to extract contract from $REF"
    exit 0
  fi
  mv -f "$TMP" "$CONTRATO"
  CAMBIO=" · contract UPDATED — see changes: git -C $DIR log -p -1 $REF -- CLAUDE.md"
fi

# 2.5 Construir y verificar caché MANDATORY
CACHE_ANTERIOR=""
if [[ -f "$CACHE_STATE" ]]; then
  CACHE_ANTERIOR="$(cat "$CACHE_STATE")"
fi

MANDATORY_ACTUAL="$(extract_mandatory "$CONTRATO")"
CACHE_ACTUAL="$(echo "$MANDATORY_ACTUAL" | sha256sum | awk '{print $1}')"

CACHE_CAMBIO=""
if [[ "$CACHE_ANTERIOR" != "$CACHE_ACTUAL" ]]; then
  echo "$CACHE_ACTUAL" > "$CACHE_STATE"
  CACHE_CAMBIO=" · MANDATORY cache built"
fi

# 3. Aplicar la política aprobada al settings local
if ! python3 "$DIR/merge_settings.py"; then
  say "⚠️ claude-sync: failed to apply policy — check settings.shared.json"
  exit 0
fi

# 4. Confirmar en voz alta qué contrato rige en esta máquina
VIGENTE="$(git log -1 --format='%h (%ad)' --date=short "$REF" -- CLAUDE.md settings.shared.json)"
say "✅ claude-sync · Contract-Id loaded: ${VIGENTE}${CAMBIO}${CACHE_CAMBIO}${NOTA}"
exit 0
