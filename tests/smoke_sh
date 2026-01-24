#!/usr/bin/env bash
set -euo pipefail

# tests/smoke.sh
# Smoke tests minimi per GroqBash: --version e --dry-run (estrazione JSON robusta)
# Exit codes:
#  0 = success
#  1 = generic failure (test assertion)
#  2 = environment/setup failure

GROQSH="./bin/groqbash"

echo "Eseguo smoke test su: $GROQSH"
echo

# Ensure the script exists and is executable
if [ ! -x "$GROQSH" ]; then
  echo "ERRORE: $GROQSH non trovato o non eseguibile"
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

# Extract only the JSON portion: find first line that begins (optionally after whitespace) with { or [
LINENO="$(printf '%s\n' "$DRY_OUT_TRIMMED" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"

if [ -z "$LINENO" ]; then
  echo "  FAIL: impossibile trovare l'inizio del JSON nell'output"
  echo "  Output completo:"
  echo "$DRY_OUT_TRIMMED"
  exit 1
fi

JSON_ONLY="$(printf '%s\n' "$DRY_OUT_TRIMMED" | tail -n +"$LINENO")"

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
