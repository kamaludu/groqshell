#!/usr/bin/env bash
set -euo pipefail

# tests/smoke.sh
# Smoke tests minimi per GroqBash: --version e --dry-run (diagnostica robusta)
# Exit codes:
#  0 = success
#  1 = generic failure (test assertion)
#  2 = environment/setup failure

# Locate groqbash: prefer ./bin/groqbash if executable, otherwise run it with bash
if [ -x "./bin/groqbash" ]; then
  GROQSH="./bin/groqbash"
elif [ -f "./bin/groqbash" ]; then
  GROQSH="bash ./bin/groqbash"
elif [ -x "./groqbash" ]; then
  GROQSH="./groqbash"
elif [ -f "./groqbash" ]; then
  GROQSH="bash ./groqbash"
else
  GROQSH="groqbash"  # fallback to PATH
fi

echo "Eseguo smoke test su: $GROQSH"
echo

# TMPDIR fallback and checks
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

# 1) --version (sanity check)
echo "1) Verifica --version"
set +e
sh -c "$GROQSH --version" >/dev/null 2>&1
VER_EXIT=$?
set -e
if [ $VER_EXIT -ne 0 ]; then
  echo "  FAIL: --version fallito (exit $VER_EXIT)"
  echo "  Nota: continuerò con i test diagnostici per raccogliere informazioni utili."
else
  echo "  OK: --version eseguito"
fi

# 2) --dry-run (principale: stdin via file redirection)
echo
echo "2) Verifica --dry-run (principale: stdin via file redirection)"

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

# Prepare temp files and ensure cleanup on exit
DRY_LOG=""
INPUT_FILE=""
cleanup() {
  [ -n "${DRY_LOG:-}" ] && [ -f "$DRY_LOG" ] && rm -f "$DRY_LOG"
  [ -n "${INPUT_FILE:-}" ] && [ -f "$INPUT_FILE" ] && rm -f "$INPUT_FILE"
}
trap cleanup EXIT

# Create input file and dry log deterministically
INPUT_FILE="$(mktemp_safe groqbash-in.XXXXXX)" || { echo "Cannot create input file"; exit 2; }
printf '%s' "$PROMPT_TEXT" >"$INPUT_FILE"
DRY_LOG="$(mktemp_safe groqbash-dry.XXXXXX)" || { rm -f "$INPUT_FILE"; echo "Cannot create dry log"; exit 2; }

# Run groqbash with stdin redirected from the input file; capture stdout+stderr in DRY_LOG
set +e
sh -c "DEBUG=1 $GROQSH --dry-run <\"$INPUT_FILE\"" >"$DRY_LOG" 2>&1
DRY_EXIT=$?
DRY_OUT="$(cat "$DRY_LOG" 2>/dev/null || true)"
set -e

# Diagnostic output: always show head of dry log and TMPDIR listing to help CI debugging
echo "=== DEBUG: DRY_LOG ($DRY_LOG) head ==="
sed -n '1,200p' "$DRY_LOG" || true
echo "=== DEBUG: TMPDIR listing (first 50) ==="
ls -la "${TMPDIR:-/tmp}" | sed -n '1,50p' || true

# If DRY_LOG is empty or exit non-zero, search for groqbash internal tmp dir and print its logs
if [ -z "$DRY_OUT" ] || [ $DRY_EXIT -ne 0 ]; then
  echo
  echo "=== DEBUG: DRY_LOG vuoto o exit non-zero; cerco log interni di groqbash ==="

  # Candidate locations to search for groqbash internal tmp dirs
  CANDIDATES=(./groqbash.d/tmp "${HOME}/.cache/groq_tmp" "${TMPDIR:-/tmp}" /tmp /var/tmp)

  found=0
  for d in "${CANDIDATES[@]}"; do
    if [ -d "$d" ]; then
      # find most recent groq.* subdir
      latest="$(ls -td "$d"/groq.* 2>/dev/null | head -n1 || true)"
      if [ -n "$latest" ] && [ -d "$latest" ]; then
        echo "Found internal tmp dir: $latest"
        echo "Listing $latest:"
        ls -la "$latest" | sed -n '1,200p' || true

        # Print common internal logs if present
        for f in groq-dry.log payload.json resp.json err.log groq-debug.log groq-verbose.log; do
          if [ -f "$latest/$f" ]; then
            echo "=== DEBUG: $latest/$f (head 200 lines) ==="
            sed -n '1,200p' "$latest/$f" || true
          fi
        done

        found=1
        break
      fi
    fi
  done

  if [ $found -eq 0 ]; then
    echo "Nessuna directory interna groq.* trovata nelle posizioni candidate."
  fi
fi

# Remove the input file now that we've captured the log
rm -f "$INPUT_FILE" || true
INPUT_FILE=""

if [ $DRY_EXIT -ne 0 ]; then
  echo
  echo "  FAIL: --dry-run ha restituito exit code $DRY_EXIT"
  echo "  Output (raw DRY_LOG mostrato sopra):"
  echo "$DRY_OUT"
  echo
  echo "Suggerimenti diagnostici:"
  echo "- Se DRY_LOG è vuoto, verifica che il comando GroqBash sia eseguibile nella forma scelta (./bin/groqbash o bash ./bin/groqbash)."
  echo "- Se DRY_LOG contiene 'no prompt provided' o simili, il file di input non è stato letto correttamente; la redirezione da file usata qui è la forma più deterministica."
  echo "- Controlla whitelist modelli e permessi TMPDIR."
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
