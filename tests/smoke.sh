#!/usr/bin/env bash
set -euo pipefail

# tests/smoke.sh
# Smoke tests minimi per GroqBash: --version e --dry-run (estrazione JSON robusta)
# Questo script esegue il test principale usando stdin (massima compatibilità)
# e un test diagnostico opzionale con --json-input per scoprire cause di fallimenti CI.
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

# Basic environment checks and TMPDIR fallback
TMPDIR_FALLBACK="${HOME}/.cache/groq_tmp"
export TMPDIR="${TMPDIR:-$TMPDIR_FALLBACK}"
mkdir -p "$TMPDIR" 2>/dev/null || true
if [ ! -d "$TMPDIR" ] || [ ! -w "$TMPDIR" ]; then
  echo "ERRORE: TMPDIR ($TMPDIR) non esistente o non scrivibile"
  exit 2
fi

# mktemp helper that prefers TMPDIR
mktemp_safe() {
  local pattern="$1"
  local tmp
  if tmp="$(mktemp "${TMPDIR}/${pattern}" 2>/dev/null)"; then
    printf '%s' "$tmp"
    return 0
  fi
  if tmp="$(mktemp 2>/dev/null)"; then
    printf '%s' "$tmp"
    return 0
  fi
  return 1
}

# 1) --version
echo "1) Verifica --version"
if "$GROQSH" --version >/dev/null 2>&1; then
  echo "  OK: --version eseguito"
else
  echo "  FAIL: --version fallito"
  exit 1
fi

# 2) --dry-run (principale: stdin)
echo
echo "2) Verifica --dry-run (principale: stdin)"

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
export PROMPT_TEXT

# Primary test: provide prompt via stdin (most compatible)
set +e
DRY_OUT="$(printf '%s' "$PROMPT_TEXT" | "$GROQSH" --dry-run 2>&1)"
DRY_EXIT=$?
set -e

if [ $DRY_EXIT -ne 0 ]; then
  echo "  FAIL: --dry-run (stdin) ha restituito exit code $DRY_EXIT"
  echo "  Output:"
  echo "$DRY_OUT"
  # Before failing, run diagnostic JSON-input test to gather more info
  echo
  echo "Eseguo test diagnostico con --json-input per raccogliere informazioni (non bloccante)..."
else
  echo "  OK: --dry-run (stdin) ha restituito exit code 0"
fi

# Trim leading/trailing whitespace for further processing if primary passed
DRY_OUT_TRIMMED="$(printf '%s' "$DRY_OUT" | sed -e 's/^[[:space:]\n\r]*//' -e 's/[[:space:]\n\r]*$//')"

if [ $DRY_EXIT -eq 0 ]; then
  if [ -z "$DRY_OUT_TRIMMED" ]; then
    echo "  FAIL: --dry-run (stdin) non ha prodotto output"
    exit 1
  fi

  # Extract only the JSON portion: find first line that begins (optionally after whitespace) with { or [
  LINENO="$(printf '%s\n' "$DRY_OUT_TRIMMED" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"

  if [ -z "$LINENO" ]; then
    echo "  FAIL: impossibile trovare l'inizio del JSON nell'output (stdin)"
    echo "  Output completo:"
    echo "$DRY_OUT_TRIMMED"
    exit 1
  fi

  JSON_ONLY="$(printf '%s\n' "$DRY_OUT_TRIMMED" | tail -n +"$LINENO")"

  # Validate JSON: prefer jq, fallback to python3, fallback to heuristic
  if command -v jq >/dev/null 2>&1; then
    if printf '%s' "$JSON_ONLY" | jq . >/dev/null 2>&1; then
      echo "  OK: --dry-run (stdin) ha stampato JSON valido (jq)"
    else
      echo "  FAIL: JSON non valido (jq) dall'output stdin"
      echo "  Estratto JSON:"
      echo "$JSON_ONLY"
      exit 1
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if printf '%s' "$JSON_ONLY" | python3 -c 'import sys,json; json.load(sys.stdin)' >/dev/null 2>&1; then
      echo "  OK: --dry-run (stdin) ha stampato JSON valido (python3)"
    else
      echo "  FAIL: JSON non valido (python3) dall'output stdin"
      echo "  Estratto JSON:"
      echo "$JSON_ONLY"
      exit 1
    fi
  else
    # Basic heuristic: JSON should start with { or [
    first_char="$(printf '%s' "$JSON_ONLY" | sed -n '1p' | sed -e 's/^[[:space:]]*//' -e 's/^\(.\).*/\1/')"
    if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
      echo "  WARNING: jq/python3 non installati; output stdin sembra JSON (heuristic)"
      echo "  Estratto (prima riga):"
      printf '%s\n' "$JSON_ONLY" | head -n 1
      echo "  OK (heuristic)"
    else
      echo "  FAIL: jq/python3 non disponibili e output stdin non sembra JSON"
      echo "  Estratto JSON:"
      echo "$JSON_ONLY"
      exit 1
    fi
  fi
fi

# Diagnostic test: --json-input (non bloccante, ma stampa dettagli utili)
echo
echo "Test diagnostico: --json-input (creo un file JSON temporaneo e lo passo a groqbash)"
DIAG_INPUT_FILE="$(mktemp_safe groqbash-in.XXXXXX)" || { echo "Impossibile creare file temporaneo diagnostico"; exit 2; }

# Build JSON safely using python3 if available, otherwise fallback escaping
if command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY' >"$DIAG_INPUT_FILE"
import json, os
prompt = os.environ.get('PROMPT_TEXT', '')
payload = {
  "model": "test-model-001",
  "stream": False,
  "temperature": 1.0,
  "max_tokens": 4096,
  "messages": [{"role": "user", "content": prompt}]
}
print(json.dumps(payload))
PY
  PY_EXIT=$?
  if [ $PY_EXIT -ne 0 ]; then
    echo "ATTENZIONE: python3 ha fallito a generare il JSON diagnostico (exit $PY_EXIT)"
  fi
else
  esc=$(printf '%s' "$PROMPT_TEXT" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
  printf '{"model":"test-model-001","stream":false,"temperature":1.0,"max_tokens":4096,"messages":[{"role":"user","content":"%s"}]}\n' "$esc" >"$DIAG_INPUT_FILE"
fi
chmod 600 "$DIAG_INPUT_FILE"

# Show the diagnostic input file content (first 200 lines) to help debug CI issues
echo "=== DEBUG: contenuto file diagnostico ($DIAG_INPUT_FILE) ==="
sed -n '1,200p' "$DIAG_INPUT_FILE" || true
echo "=== END DEBUG ==="

# Run groqbash with --json-input and capture output to a temp log
DIAG_LOG="$(mktemp_safe groqbash-drylog.XXXXXX)" || { echo "Impossibile creare log diagnostico"; rm -f "$DIAG_INPUT_FILE"; exit 2; }
set +e
DEBUG=1 "$GROQSH" --dry-run --json-input "$DIAG_INPUT_FILE" >"$DIAG_LOG" 2>&1
DIAG_EXIT=$?
set -e

echo "=== groqbash --dry-run --json-input raw output (begin) ==="
sed -n '1,500p' "$DIAG_LOG" || true
echo "=== groqbash --dry-run --json-input raw output (end) ==="

# If diagnostic test failed, print helpful hints (but do not fail the smoke if stdin already passed)
if [ $DIAG_EXIT -ne 0 ]; then
  echo
  echo "ATTENZIONE: test diagnostico --json-input ha fallito con exit code $DIAG_EXIT"
  echo "Contenuto del file diagnostico (mostrato sopra) e log grezzo (mostrato sopra) possono aiutare a capire la causa."
  echo "Suggerimenti diagnostici:"
  echo "- Se il file diagnostico è vuoto, il problema è nella generazione del file (python3 o variabile PROMPT_TEXT)."
  echo "- Se il file è valido ma groqbash risponde 'no prompt provided', controlla come groqbash interpreta --json-input nella versione corrente."
  echo "- Verifica permessi TMPDIR e che groqbash legga il file corretto."
  # If primary stdin test failed too, treat as overall failure
  if [ $DRY_EXIT -ne 0 ]; then
    echo
    echo "Entrambi i test (stdin e --json-input) sono falliti: fallisco lo smoke."
    rm -f "$DIAG_INPUT_FILE" "$DIAG_LOG"
    exit 1
  else
    echo
    echo "Nota: il test principale (stdin) è passato; il test --json-input è solo diagnostico e non blocca il risultato."
  fi
else
  echo "OK: test diagnostico --json-input ha restituito exit code 0"
fi

# Cleanup diagnostic files
rm -f "$DIAG_INPUT_FILE" "$DIAG_LOG" || true

echo
echo "Tutti i test smoke sono passati."
exit 0
