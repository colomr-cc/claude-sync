#!/usr/bin/env bash
# Verifica que el caché MANDATORY está activo y sincronizado.
# Sin falsos positivos: comprueba archivos y hashes de verdad.
set -uo pipefail

CONTRATO="$HOME/.claude/CLAUDE.md"
CACHE_STATE="$HOME/.claude/MANDATORY.cache"

# Validar que archivos existen
if [[ ! -f "$CONTRATO" ]]; then
  echo "❌ MANDATORY cache: contract file not found at $CONTRATO"
  exit 1
fi

if [[ ! -f "$CACHE_STATE" ]]; then
  echo "❌ MANDATORY cache: cache state file missing at $CACHE_STATE"
  exit 1
fi

# Extraer bloque MANDATORY actual
extract_mandatory() {
  local file="$1"
  local start end

  start=$(grep -n "^## MANDATORY CHECKLIST$" "$file" | cut -d: -f1)
  if [[ -z "$start" ]]; then
    return 1
  fi

  end=$(tail -n +$((start + 1)) "$file" | grep -n "^## " | head -n1 | cut -d: -f1)
  if [[ -z "$end" ]]; then
    tail -n +$start "$file"
  else
    sed -n "${start},$((start + end - 2))p" "$file"
  fi
}

# Calcular hash actual
MANDATORY_ACTUAL="$(extract_mandatory "$CONTRATO")"
if [[ -z "$MANDATORY_ACTUAL" ]]; then
  echo "❌ MANDATORY cache: could not extract MANDATORY CHECKLIST block"
  exit 1
fi

HASH_ACTUAL="$(echo "$MANDATORY_ACTUAL" | sha256sum | awk '{print $1}')"
HASH_GUARDADO="$(cat "$CACHE_STATE")"

# Verificar match
if [[ "$HASH_ACTUAL" == "$HASH_GUARDADO" ]]; then
  echo "✅ MANDATORY cache active: $HASH_ACTUAL"
  exit 0
else
  echo "⚠️ MANDATORY cache mismatch"
  echo "  Current:  $HASH_ACTUAL"
  echo "  Expected: $HASH_GUARDADO"
  echo "  (Run 'claude-sync' to rebuild or check for changes)"
  exit 1
fi
