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
REF="origin/main"

say() {
  local msg="$1"
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg" "$msg"
  return 0
}

cd "$DIR" || { say "⚠️ claude-config: no existe $DIR — revisar la instalación"; exit 0; }

# 1. Traer la referencia aprobada. Sin red se sigue con la última conocida.
NOTA=""
if ! git fetch --quiet origin main 2>/dev/null; then
  NOTA=" · ⚠️ sin acceso a origin: se aplica la última referencia local"
fi

if ! git rev-parse --verify --quiet "$REF" >/dev/null; then
  say "⚠️ claude-config: no existe la referencia $REF — revisar la instalación"
  exit 0
fi

# 2. Materializar el contrato aprobado si difiere del que hay en ~/.claude
ACTUAL=""
MIGRACION=""
if [[ -L "$CONTRATO" ]]; then
  # Symlink de la versión anterior: el contrato dependía del árbol de trabajo.
  # Se materializa siempre, aunque el contenido apuntado coincida.
  MIGRACION=" (materializado: ya no es un enlace al árbol de trabajo)"
elif [[ -f "$CONTRATO" ]]; then
  ACTUAL="$(git hash-object "$CONTRATO")"
fi
APROBADO="$(git rev-parse "$REF:CLAUDE.md" 2>/dev/null)"

CAMBIO=""
if [[ -z "$APROBADO" ]]; then
  say "⚠️ claude-config: no se encuentra CLAUDE.md en $REF"
  exit 0
fi
if [[ "$ACTUAL" != "$APROBADO" ]]; then
  mkdir -p "$(dirname "$CONTRATO")"
  TMP="$(mktemp)"
  if ! git show "$REF:CLAUDE.md" > "$TMP"; then
    rm -f "$TMP"
    say "⚠️ claude-config: no se pudo extraer el contrato de $REF"
    exit 0
  fi
  mv -f "$TMP" "$CONTRATO"   # sustituye también un symlink antiguo
  if [[ -n "$MIGRACION" ]]; then
    CAMBIO=" · contrato${MIGRACION}"
  else
    CAMBIO=" · contrato ACTUALIZADO — ver cambios: git -C $DIR log -p -1 $REF -- CLAUDE.md"
  fi
fi

# 3. Aplicar la política aprobada al settings local
if ! python3 "$DIR/merge_settings.py"; then
  say "⚠️ claude-config: no se pudo aplicar la política — revisar settings.shared.json"
  exit 0
fi

# 4. Confirmar en voz alta qué contrato rige en esta máquina
VIGENTE="$(git log -1 --format='%h (%ad)' --date=short "$REF" -- CLAUDE.md settings.shared.json)"
say "✅ claude-config · contrato en vigor: ${VIGENTE}${CAMBIO}${NOTA}"
exit 0
