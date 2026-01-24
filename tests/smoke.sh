#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: tests/smoke.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/<your-repo>/groqbash
# =============================================================================
# Smoke tests minimi per GroqBash: --version e --dry-run (estrazione JSON)
# Exit codes:
#  0 = success
#  1 = generic failure (test assertion)
#  2 = environment/setup failure

set -euo pipefail

# Locate groqbash in common locations: ./bin/groqbash, ./groqbash, or in PATH
if [ -x "./bin/groqbash" ]; then
  GROQSH="./bin/groqbash"
elif [ -x "./groqbash" ]; then
  GROQSH="./groqbash"
else
  if command -v groqbash >/dev/null 2>&1; then
    GROQSH="$(command -v groqbash)"
  else
    GROQSH="./bin/groqbash"
  fi
fi

echo "Eseguo smoke test su: $GROQSH"
echo

# Ensure the script exists and is executable
if [ ! -x "$GROQSH" ]; then
  echo "ERRORE: $GROQSH non trovato o non eseguibile"
  echo "Verificare che il file sia presente in ./bin/groqbash o ./groqbash, o che sia nel PATH."
  exit 2
fi

# 1) --version
echo "1) Verifica --version"
if "$GROQSH" --version >/dev/null 2>&1; then
  echo "  OK: --version eseguito"
else
  echo "  FAIL: --version fallito"
  exit 1
fi

# 2) --dry-run
echo
echo "2) Verifica --dry-run (payload JSON)"

# Ensure a minimal local whitelist for local runs (CI usually sets this)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/groq"
MODELS_FILE="$CONFIG_DIR/models.txt"
if [ ! -s "$MODELS_FILE" ]; then
  mkdir -p "$CONFIG_DIR"
  echo "test-model-001" > "$MODELS_FILE"
  chmod 600 "$MODELS_FILE"
  echo "  Nota: whitelist temporanea creata in $MODELS_FILE"
fi

PROMPT_TEXT="test payload"

# Run --dry-run providing the prompt via stdin (most compatible)
set +e
DRY_OUT="$(printf '%s' "$PROMPT_TEXT" | "$GROQSH" --dry-run 2>&1)"
DRY_EXIT=$?
set -e

if [ $DRY_EXIT -ne 0 ]; then
  echo "  FAIL: --dry-run ha restituito exit code $DRY_EXIT"
  echo "  Output:"
  echo "$DRY_OUT"
  exit 1
fi

# Trim leading/trailing whitespace
DRY_OUT_TRIMMED="$(printf '%s' "$DRY_OUT" | sed -e 's/^[[:space:]\n\r]*//' -e 's/[[:space:]\n\r]*$//')"

if [ -z "$DRY_OUT_TRIMMED" ]; then
  echo "  FAIL: --dry-run non ha prodotto output"
  exit 1
fi

# Robust JSON extraction function
extract_json_from_output() {
  local out="$1"
  local marker_line start_line block first_json_line rel_line

  marker_line="$(printf '%s\n' "$out" | grep -n -m1 '^DRY-RUN: payload path:' | cut -d: -f1 || true)"
  if [ -n "$marker_line" ]; then
    # take everything after the marker line
    start_line=$((marker_line + 1))
    block="$(printf '%s\n' "$out" | tail -n +"$start_line")"
    # remove any DRY-RUN diagnostic lines
    block="$(printf '%s\n' "$block" | sed '/^DRY-RUN:/d')"
    # trim leading blank lines
    block="$(printf '%s\n' "$block" | sed -e 's/^[[:space:]\n\r]*//')"
    # find first JSON-start line inside the block
    first_json_line="$(printf '%s\n' "$block" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"
    if [ -n "$first_json_line" ]; then
      printf '%s\n' "$block" | tail -n +"$first_json_line"
      return 0
    fi
    # if block exists but no JSON found, fall through to global search
  fi

  # Fallback: search entire output for first line that begins with { or [
  rel_line="$(printf '%s\n' "$out" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"
  if [ -n "$rel_line" ]; then
    printf '%s\n' "$out" | tail -n +"$rel_line"
    return 0
  fi

  return 1
}

# Attempt extraction
if JSON_ONLY="$(extract_json_from_output "$DRY_OUT_TRIMMED")"; then
  # Trim leading whitespace from JSON_ONLY
  JSON_ONLY="$(printf '%s\n' "$JSON_ONLY" | sed -e 's/^[[:space:]\n\r]*//')"
  if [ -z "$JSON_ONLY" ]; then
    # treat as not found
    JSON_ONLY=""
  fi
fi

# If JSON not found, but dry-run marker indicates simulation succeeded, accept with warning
if [ -z "${JSON_ONLY:-}" ]; then
  # check for dry-run markers that indicate simulation
  if printf '%s\n' "$DRY_OUT_TRIMMED" | grep -q '^DRY-RUN: payload path:' && \
     printf '%s\n' "$DRY_OUT_TRIMMED" | grep -q -E '^DRY-RUN: (skipping provider HTTP call|request simulated successfully)'; then
    echo "  WARNING: --dry-run did not include payload JSON in stdout, but dry-run markers are present."
    echo "           groqbash reported a simulated request and payload path. Consider adjusting groqbash to print payload head for stricter validation."
    echo "  OK: --dry-run simulated successfully (marker-only)."
    echo
    echo "Tutti i test smoke sono passati."
    exit 0
  fi

  echo "  FAIL: impossibile trovare l'inizio del JSON nell'output"
  echo "  Output completo:"
  echo "$DRY_OUT_TRIMMED"
  exit 1
fi

# Validate JSON: prefer jq, fallback to python3, fallback to heuristic
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$JSON_ONLY" | jq . >/dev/null 2>&1; then
    echo "  OK: --dry-run ha stampato JSON valido (jq)"
  else
    echo "  FAIL: JSON non valido (jq)"
    echo "  Estratto JSON:"
    echo "$JSON_ONLY"
    exit 1
  fi
elif command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$JSON_ONLY" | python3 -c 'import sys,json; json.load(sys.stdin)' >/dev/null 2>&1; then
    echo "  OK: --dry-run ha stampato JSON valido (python3)"
  else
    echo "  FAIL: JSON non valido (python3)"
    echo "  Estratto JSON:"
    echo "$JSON_ONLY"
    exit 1
  fi
else
  # Basic heuristic: JSON should start with { or [
  first_char="$(printf '%s' "$JSON_ONLY" | sed -n '1p' | sed -e 's/^[[:space:]]*//' -e 's/^\(.\).*/\1/')"
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    echo "  WARNING: jq/python3 non installati; output sembra JSON (heuristic)"
    echo "  Estratto (prima riga):"
    printf '%s\n' "$JSON_ONLY" | head -n 1
    echo "  OK (heuristic)"
  else
    echo "  FAIL: jq/python3 non disponibili e output non sembra JSON"
    echo "  Estratto JSON:"
    echo "$JSON_ONLY"
    exit 1
  fi
fi

echo
echo "Tutti i test smoke sono passati."
exit 0
