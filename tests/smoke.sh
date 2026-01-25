#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: tests/smoke.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
set -euo pipefail

# tests/smoke.sh
# Robust smoke test per GroqBash --dry-run
# - Individua il binario in modo robusto
# - Cattura l'output completo di --dry-run
# - Estrae JSON candidato dopo il marker "DRY-RUN: payload path:" oppure con fallback alla prima riga che inizia con { o [
# - Pulisce spazi iniziali e valida con jq (o python3 come fallback)
# - Fallisce solo se non trova JSON o la validazione fallisce
#
# Exit codes:
#  0 = success
#  1 = test assertion failure
#  2 = environment/setup failure

# --- Locate groqbash binary robustly
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

# --- TMPDIR fallback and checks
TMPDIR_FALLBACK="${HOME}/.cache/groq_tmp"
export TMPDIR="${TMPDIR:-$TMPDIR_FALLBACK}"
mkdir -p "$TMPDIR" 2>/dev/null || true
if [ ! -d "$TMPDIR" ] || [ ! -w "$TMPDIR" ]; then
  echo "FAIL: TMPDIR ($TMPDIR) non esistente o non scrivibile"
  exit 2
fi

# --- mktemp helper preferring TMPDIR
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

# --- --version sanity check (non-fatal)
echo "1) Verifica --version"
set +e
sh -c "$GROQSH --version" >/dev/null 2>&1
VER_EXIT=$?
set -e
if [ $VER_EXIT -ne 0 ]; then
  echo "  WARN: --version fallito (exit $VER_EXIT) — continuo con diagnostica"
else
  echo "  OK: --version eseguito"
fi

# --- Prepare minimal whitelist if missing (safe, non-invasive)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/groq"
MODELS_FILE="$CONFIG_DIR/models.txt"
if [ ! -s "$MODELS_FILE" ]; then
  mkdir -p "$CONFIG_DIR"
  echo "test-model-001" > "$MODELS_FILE"
  chmod 600 "$MODELS_FILE" || true
  echo "  Nota: whitelist temporanea creata in $MODELS_FILE"
fi

# --- Prepare input and capture files
PROMPT_TEXT="test payload"
INPUT_FILE="$(mktemp_safe groqbash-in.XXXXXX)" || { echo "FAIL: cannot create input file"; exit 2; }
printf '%s' "$PROMPT_TEXT" >"$INPUT_FILE"

DRY_LOG="$(mktemp_safe groqbash-dry.XXXXXX)" || { rm -f "$INPUT_FILE"; echo "FAIL: cannot create dry log"; exit 2; }

cleanup() {
  [ -n "${DRY_LOG:-}" ] && [ -f "$DRY_LOG" ] && rm -f "$DRY_LOG"
  [ -n "${INPUT_FILE:-}" ] && [ -f "$INPUT_FILE" ] && rm -f "$INPUT_FILE"
}
trap cleanup EXIT

# --- Run groqbash --dry-run capturing stdout+stderr
set +e
# DEBUG=1 is safe for diagnostics; does not change groqbash logic here
sh -c "DEBUG=1 $GROQSH --dry-run <\"$INPUT_FILE\"" >"$DRY_LOG" 2>&1
DRY_EXIT=$?
DRY_OUT="$(cat "$DRY_LOG" 2>/dev/null || true)"
set -e

# Always show a short head to help CI debugging
echo "=== DEBUG: DRY_LOG head ==="
sed -n '1,200p' "$DRY_LOG" || true
echo "=== DEBUG: TMPDIR listing (first 50) ==="
ls -la "${TMPDIR:-/tmp}" | sed -n '1,50p' || true
echo

# If output empty or non-zero exit, try to surface internal groqbash logs (best-effort)
if [ -z "$DRY_OUT" ] || [ $DRY_EXIT -ne 0 ]; then
  echo "=== DEBUG: DRY_LOG vuoto o exit non-zero; cerco log interni di groqbash ==="
  CANDIDATES=(./bin/groqbash.d/tmp ./groqbash.d/tmp "${HOME}/.cache/groq_tmp" "${TMPDIR:-/tmp}" /tmp /var/tmp)
  found=0
  for d in "${CANDIDATES[@]}"; do
    if [ -d "$d" ]; then
      latest="$(ls -td "$d"/groq.* 2>/dev/null | head -n1 || true)"
      if [ -n "$latest" ] && [ -d "$latest" ]; then
        echo "Found internal tmp dir: $latest"
        ls -la "$latest" | sed -n '1,200p' || true
        for f in payload.json groq-dry.log resp.json err.log groq-debug.log groq-verbose.log; do
          if [ -f "$latest/$f" ]; then
            echo "=== DEBUG: $latest/$f (head 200) ==="
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

# If groqbash returned non-zero, fail with diagnostics
if [ $DRY_EXIT -ne 0 ]; then
  echo
  echo "FAIL: --dry-run ha restituito exit code $DRY_EXIT"
  echo "Output (raw DRY_LOG mostrato sopra):"
  echo "$DRY_OUT"
  exit 1
fi

# --- Trim leading/trailing whitespace from captured output
DRY_OUT_TRIMMED="$(printf '%s' "$DRY_OUT" | sed -e 's/^[[:space:]\n\r]*//' -e 's/[[:space:]\n\r]*$//')"

if [ -z "$DRY_OUT_TRIMMED" ]; then
  echo "FAIL: --dry-run non ha prodotto output"
  exit 1
fi

# --- Extraction strategy:
# 1) If a line beginning with "DRY-RUN: payload path:" exists, consider everything after that line as candidate JSON.
#    If the same marker line contains JSON after the marker, use that substring.
# 2) Otherwise fallback to first line that begins with { or [ and take from there to EOF.

JSON_CANDIDATE=""
MARK_LINE_NUM="$(grep -n -m1 '^DRY-RUN: payload path:' "$DRY_LOG" | cut -d: -f1 || true)"

if [ -n "$MARK_LINE_NUM" ]; then
  MARK_LINE="$(sed -n "${MARK_LINE_NUM}p" "$DRY_LOG" || true)"
  AFTER_MARK="$(printf '%s' "$MARK_LINE" | sed -e 's/^DRY-RUN: payload path:[[:space:]]*//')"
  # If remainder of marker line starts with { or [, use it
  first_char="$(printf '%s' "$AFTER_MARK" | sed -e 's/^[[:space:]]*//' -e 's/^\(.\).*/\1/' || true)"
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    JSON_CANDIDATE="$AFTER_MARK"
  else
    # take everything after the marker line to EOF as candidate
    JSON_CANDIDATE="$(sed -n "$((MARK_LINE_NUM + 1)),\$p" "$DRY_LOG" || true)"
  fi
fi

# Fallback: first line that begins with { or [
if [ -z "$JSON_CANDIDATE" ] || [ -z "$(printf '%s' "$JSON_CANDIDATE" | sed -e '1,/[^[:space:]\n\r]/!d')" ]; then
  FIRST_JSON_LINE="$(printf '%s\n' "$DRY_OUT_TRIMMED" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"
  if [ -n "$FIRST_JSON_LINE" ]; then
    JSON_CANDIDATE="$(printf '%s\n' "$DRY_OUT_TRIMMED" | tail -n +"$FIRST_JSON_LINE" || true)"
  fi
fi

# Trim leading whitespace/newlines from candidate
JSON_CANDIDATE="$(printf '%s' "$JSON_CANDIDATE" | sed -e '1,/[^[:space:]\n\r]/!d')"

# Final checks
if [ -z "$JSON_CANDIDATE" ]; then
  echo "FAIL: nessun JSON candidato trovato nell'output di --dry-run"
  echo "Output completo:"
  echo "$DRY_OUT_TRIMMED"
  exit 1
fi

# --- Validate JSON: prefer jq, fallback to python3
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$JSON_CANDIDATE" | jq . >/dev/null 2>&1; then
    echo "OK: --dry-run ha prodotto JSON valido (validato con jq)"
    echo
    echo "Tutti i test smoke sono passati."
    exit 0
  else
    echo "FAIL: JSON estratto non valido (jq)"
    echo "Estratto JSON (head 200):"
    printf '%s\n' "$JSON_CANDIDATE" | sed -n '1,200p'
    exit 1
  fi
elif command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$JSON_CANDIDATE" | python3 -c 'import sys,json; json.load(sys.stdin)' >/dev/null 2>&1; then
    echo "OK: --dry-run ha prodotto JSON valido (validato con python3)"
    echo
    echo "Tutti i test smoke sono passati."
    exit 0
  else
    echo "FAIL: JSON estratto non valido (python3)"
    echo "Estratto JSON (head 200):"
    printf '%s\n' "$JSON_CANDIDATE" | sed -n '1,200p'
    exit 1
  fi
else
  # Heuristic fallback: ensure it starts with { or [
  first_char="$(printf '%s' "$JSON_CANDIDATE" | sed -n '1p' | sed -e 's/^[[:space:]]*//' -e 's/^\(.\).*/\1/')"
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    echo "WARNING: jq/python3 non installati; output sembra JSON (heuristic)"
    echo "Estratto (prima riga):"
    printf '%s\n' "$JSON_CANDIDATE" | head -n 1
    echo
    echo "Tutti i test smoke sono passati (heuristic)"
    exit 0
  else
    echo "FAIL: jq/python3 non disponibili e output non sembra JSON"
    echo "Estratto JSON (head 200):"
    printf '%s\n' "$JSON_CANDIDATE" | sed -n '1,200p'
    exit 1
  fi
fi
