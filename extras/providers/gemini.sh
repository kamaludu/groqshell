#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/providers/gemini.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
# -------------------------
# Gemini configuration (module-local)
# Users may set GEMINI_API_KEY and GEMINI_API_URL in their environment.
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
API_URL_GEMINI="${GEMINI_API_URL:-https://api.gemini.example/v1/chat/completions}"

# -------------------------
# Minimal JSON escaper (reuse core's behavior if available)
escape_json_string() {
  if type escape_json_string >/dev/null 2>&1; then
    escape_json_string "$1"
    return $?
  fi
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# -------------------------
# build_payload_gemini
# Build a Gemini-appropriate payload (approximation).
# Uses MODEL, SYSTEM_PROMPT, CONTENT, STREAM_MODE, MAX_TOKENS, TEMP.
build_payload_gemini() {
  if [ -n "${JSON_INPUT:-}" ]; then
    cp "$JSON_INPUT" "$PAYLOAD"
    return 0
  fi
  local esc_content esc_system stream_flag
  esc_content="$(escape_json_string "$CONTENT")"
  esc_system="$(escape_json_string "$SYSTEM_PROMPT")"
  stream_flag="false"
  [ "${STREAM_MODE:-}" = "true" ] && stream_flag="true"

  # Minimal Gemini-like payload (approximation). Kept isolated in module.
  if [ -n "$SYSTEM_PROMPT" ]; then
    cat >"$PAYLOAD" <<EOF
{"model":"$MODEL","stream":$stream_flag,"input":[{"role":"system","content":"$esc_system"},{"role":"user","content":"$esc_content"}],"max_tokens":$MAX_TOKENS,"temperature":$TEMP}
EOF
  else
    cat >"$PAYLOAD" <<EOF
{"model":"$MODEL","stream":$stream_flag,"input":[{"role":"user","content":"$esc_content"}],"max_tokens":$MAX_TOKENS,"temperature":$TEMP}
EOF
  fi
}

# -------------------------
# call_api_gemini
# Non-streaming Gemini call (approximation).
call_api_gemini() {
  if [ -z "${GEMINI_API_KEY:-}" ]; then
    echo "Error: GEMINI_API_KEY is not set. Gemini support not fully configured." >&2
    return 2
  fi
  local http_file time_total http_code
  http_file="$(mktemp -p "${GROQBASH_TMPDIR:-/tmp}" gemini-http.XXXX 2>/dev/null || true)"
  if [ -z "$http_file" ]; then
    echo "Error: cannot create temporary file for HTTP code." >&2
    return 1
  fi
  if [ "${DEBUG:-0}" -eq 1 ]; then
    dbg "Running curl (Gemini non-streaming) with timing..."
    curl --silent --show-error --max-time 120 -H "Authorization: Bearer $GEMINI_API_KEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" -o "$RESP" -w '%{http_code} %{time_total}' "$API_URL_GEMINI" 2>"$ERRF" >"$http_file" || true
  else
    curl --silent --show-error --max-time 120 -H "Authorization: Bearer $GEMINI_API_KEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" -o "$RESP" -w '%{http_code} %{time_total}' "$API_URL_GEMINI" 2>"$ERRF" >"$http_file" || true
  fi
  read -r http_code time_total < "$http_file" 2>/dev/null || { http_code="$(cat "$http_file" 2>/dev/null || echo "000")"; time_total="0"; }
  rm -f "$http_file" 2>/dev/null || true
  dbg "Gemini HTTP code: $http_code"
  dbg "Gemini request time (s): $time_total"
  case "$http_code" in
    2*) return 0 ;;
    *)
      dbg "Gemini HTTP error code: $http_code"
      dbg "Gemini response (head):"; head -n 200 "$RESP" >&2 || true
      dbg "Gemini curl stderr (head):"; head -n 200 "$ERRF" >&2 || true
      return 1
      ;;
  esac
}

# -------------------------
# call_api_streaming_gemini
# Streaming parser for Gemini-like streams (approximation).
call_api_streaming_gemini() {
  if [ -z "${GEMINI_API_KEY:-}" ]; then
    echo "Error: GEMINI_API_KEY is not set. Gemini streaming not configured." >&2
    return 2
  fi

  local start_ts end_ts elapsed rc
  start_ts="$(date +%s.%N 2>/dev/null || date +%s)"
  if [ "${DEBUG:-0}" -eq 1 ]; then
    dbg "Starting streaming curl (Gemini placeholder)..."
  fi

  rc=0
  # Minimal, documented approximation: read line-by-line and extract "content" fields if present.
  curl $CURL_BASE_OPTS -H "Authorization: Bearer $GEMINI_API_KEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" "$API_URL_GEMINI" 2>"$ERRF" | tee "$RESP" | \
  while IFS= read -r line; do
    # Attempt to extract a "content" field in JSON fragments; best-effort.
    if printf '%s' "$line" | grep -q '"content"'; then
      raw="$(printf '%s' "$line" | sed -nE 's/.*"content"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')"
      if [ -n "$raw" ]; then
        chunk="$(printf '%s' "$raw" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
        printf '%s' "$chunk"
      fi
    else
      # If line looks like plain text, print it
      printf '%s' "$line"
    fi
  done

  rc=${PIPESTATUS[0]:-0}
  end_ts="$(date +%s.%N 2>/dev/null || date +%s)"
  if command -v awk >/dev/null 2>&1; then
    elapsed="$(awk "BEGIN{printf \"%.3f\", $end_ts - $start_ts}")"
  else
    elapsed="unknown"
  fi
  dbg "Gemini streaming curl exit code: $rc"
  dbg "Gemini streaming elapsed time (s): $elapsed"
  if [ "$rc" -ne 0 ]; then
    dbg "Gemini curl stderr (head):"; head -n 50 "$ERRF" >&2 || true
    return 1
  fi
  return 0
}

# End of gemini.sh
