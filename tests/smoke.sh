#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: tests/smoke.sh
# Robust smoke test for GroqBash --dry-run
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
set -euo pipefail

# Locate groqbash binary in order: ./bin/groqbash, ./groqbash, groqbash in PATH
if [ -x "./bin/groqbash" ]; then
  GROQSH="./bin/groqbash"
elif [ -f "./bin/groqbash" ]; then
  GROQSH="bash ./bin/groqbash"
elif [ -x "./groqbash" ]; then
  GROQSH="./groqbash"
elif [ -f "./groqbash" ]; then
  GROQSH="bash ./groqbash"
elif command -v groqbash >/dev/null 2>&1; then
  GROQSH="$(command -v groqbash)"
else
  echo "FAIL: groqbash non trovato. Assicurati che ./bin/groqbash o ./groqbash esistano o che groqbash sia nel PATH."
  exit 2
fi

JSON_FILE="tests/good.json"
if [ ! -f "$JSON_FILE" ]; then
  echo "FAIL: $JSON_FILE non trovato. Assicurati che il file esista nel repository."
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq non installato. Installare jq nel runner CI."
  exit 2
fi

DRY_LOG="$(mktemp 2>/dev/null || mktemp -t groqbash-dry.XXXXXX)"
trap 'rm -f "$DRY_LOG"' EXIT

# Run groqbash --dry-run capturing stdout+stderr
set +e
DEBUG=1 "$GROQSH" --dry-run "$JSON_FILE" >"$DRY_LOG" 2>&1
DRY_EXIT=$?
DRY_OUT="$(cat "$DRY_LOG" 2>/dev/null || true)"
set -e

if [ $DRY_EXIT -ne 0 ]; then
  echo "FAIL: --dry-run ha restituito exit code $DRY_EXIT"
  if [ -s "$DRY_LOG" ]; then
    echo "Output (raw):"
    sed -n '1,200p' "$DRY_LOG"
  else
    echo "Output vuoto."
  fi
  exit 1
fi

DRY_OUT_TRIMMED="$(printf '%s' "$DRY_OUT" | sed -e 's/^[[:space:]\n\r]*//' -e 's/[[:space:]\n\r]*$//')"

if [ -z "$DRY_OUT_TRIMMED" ]; then
  echo "FAIL: --dry-run non ha prodotto output"
  exit 1
fi

# Extraction strategy:
# 1) If a line beginning with "DRY-RUN: payload path:" exists, everything after that line is candidate JSON.
#    If the same marker line contains JSON after the marker, use that substring.
# 2) Otherwise fallback to first line that begins with { or [ and take from there to EOF.
JSON_CANDIDATE=""

MARK_LINE_NUM="$(grep -n -m1 '^DRY-RUN: payload path:' "$DRY_LOG" | cut -d: -f1 || true)"
if [ -n "$MARK_LINE_NUM" ]; then
  MARK_LINE="$(sed -n "${MARK_LINE_NUM}p" "$DRY_LOG" || true)"
  AFTER_MARK="$(printf '%s' "$MARK_LINE" | sed -e 's/^DRY-RUN: payload path:[[:space:]]*//')"
  first_char="$(printf '%s' "$AFTER_MARK" | sed -e 's/^[[:space:]]*//' -e 's/^\(.\).*/\1/' || true)"
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    JSON_CANDIDATE="$AFTER_MARK"
  else
    JSON_CANDIDATE="$(sed -n "$((MARK_LINE_NUM + 1)),\$p" "$DRY_LOG" || true)"
  fi
fi

if [ -z "$JSON_CANDIDATE" ] || [ -z "$(printf '%s' "$JSON_CANDIDATE" | sed -e '1,/[^[:space:]\n\r]/!d')" ]; then
  FIRST_JSON_LINE="$(printf '%s\n' "$DRY_OUT_TRIMMED" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"
  if [ -n "$FIRST_JSON_LINE" ]; then
    JSON_CANDIDATE="$(printf '%s\n' "$DRY_OUT_TRIMMED" | tail -n +"$FIRST_JSON_LINE" || true)"
  fi
fi

# Trim leading whitespace/newlines from candidate
JSON_CANDIDATE="$(printf '%s' "$JSON_CANDIDATE" | sed -e '1,/[^[:space:]\n\r]/!d')"

if [ -z "$JSON_CANDIDATE" ]; then
  echo "FAIL: nessun JSON candidato trovato nell'output di --dry-run"
  exit 1
fi

# Validate JSON with jq
if printf '%s' "$JSON_CANDIDATE" | jq . >/dev/null 2>&1; then
  echo "OK: --dry-run ha prodotto JSON valido (validato con jq)"
  exit 0
else
  echo "FAIL: JSON estratto non valido (jq)"
  echo "Estratto JSON (head 200):"
  printf '%s\n' "$JSON_CANDIDATE" | sed -n '1,200p'
  exit 1
fi
