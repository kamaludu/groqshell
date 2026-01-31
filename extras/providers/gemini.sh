#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/providers/gemini.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
set -euo pipefail

GEMINIAPIKEY="${GEMINIAPIKEY:-}"

_get_work_tmpdir_gemini() {
  if [ -n "${RUN_TMPDIR:-}" ] && [ -d "${RUN_TMPDIR:-}" ]; then
    printf '%s' "$RUN_TMPDIR"
    return 0
  fi
  if [ -n "${GROQBASH_TMPDIR:-}" ] && [ -d "${GROQBASH_TMPDIR:-}" ]; then
    printf '%s' "$GROQBASH_TMPDIR"
    return 0
  fi
  if type make_tmpdir >/dev/null 2>&1; then
    local d
    d="$(make_tmpdir 2>/dev/null || true)"
    if [ -n "$d" ] && [ -d "$d" ]; then
      printf '%s' "$d"
      return 0
    fi
  fi
  return 1
}

_mktemp_in_dir_gemini() {
  local dir="$1" tmpf
  [ -z "$dir" ] && return 1
  [ ! -d "$dir" ] && return 1
  tmpf="$(mktemp -p "$dir" gemini-XXXX 2>/dev/null || true)"
  [ -z "$tmpf" ] && return 1
  printf '%s' "$tmpf"
  return 0
}

buildpayloadgemini() {
  local workdir tmp_payload model_in_file model_to_use user_prompt
  workdir="$(_get_work_tmpdir_gemini)" || return $GROQBASHERRTMP
  tmp_payload="$(_mktemp_in_dir_gemini "$workdir")" || return $GROQBASHERRTMP
  umask 077

  if [ -n "${JSON_INPUT:-}" ]; then
    if jq -e 'has("messages")' "$JSON_INPUT" >/dev/null 2>&1; then
      cp "$JSON_INPUT" "$tmp_payload" 2>/dev/null || { rm -f "$tmp_payload" 2>/dev/null || true; return 1; }
      mv "$tmp_payload" "$PAYLOAD" 2>/dev/null || cp -f "$tmp_payload" "$PAYLOAD" 2>/dev/null || true
      chmod 600 "$PAYLOAD" 2>/dev/null || true
      return 0
    fi
    if jq -e 'has("prompt")' "$JSON_INPUT" >/dev/null 2>&1; then
      user_prompt="$(jq -r '.prompt' "$JSON_INPUT" 2>/dev/null || true)"
      model_in_file="$(jq -r '.model // empty' "$JSON_INPUT" 2>/dev/null || true)"
      model_to_use="${model_in_file:-$MODEL}"
      jq -n --arg model "$model_to_use" \
            --argjson stream "$( [ "${STREAM_MODE:-}" = "true" ] && printf 'true' || printf 'false' )" \
            --arg ture "$TURE" \
            --arg max_tokens "$MAX_TOKENS" \
            --arg user "$user_prompt" \
            '{model:$model, stream:$stream, temperature:($ture|tonumber), max_tokens:($max_tokens|tonumber), messages:[{role:"user",content:$user}] }' >"$tmp_payload"
      mv "$tmp_payload" "$PAYLOAD" 2>/dev/null || cp -f "$tmp_payload" "$PAYLOAD" 2>/dev/null || true
      chmod 600 "$PAYLOAD" 2>/dev/null || true
      return 0
    fi
    cp "$JSON_INPUT" "$tmp_payload" 2>/dev/null || { rm -f "$tmp_payload" 2>/dev/null || true; return 1; }
    mv "$tmp_payload" "$PAYLOAD" 2>/dev/null || cp -f "$tmp_payload" "$PAYLOAD" 2>/dev/null || true
    chmod 600 "$PAYLOAD" 2>/dev/null || true
    return 0
  fi

  if [ -n "${SYSTEM_PROMPT:-}" ]; then
    jq -n --arg model "$MODEL" \
          --argjson stream "$( [ "${STREAM_MODE:-}" = "true" ] && printf 'true' || printf 'false' )" \
          --arg ture "$TURE" \
          --arg max_tokens "$MAX_TOKENS" \
          --arg system "$SYSTEM_PROMPT" \
          --arg user "$CONTENT" \
          '{model:$model, stream:$stream, temperature:($ture|tonumber), max_tokens:($max_tokens|tonumber), messages:[{role:"system",content:$system},{role:"user",content:$user}] }' >"$tmp_payload"
  else
    jq -n --arg model "$MODEL" \
          --argjson stream "$( [ "${STREAM_MODE:-}" = "true" ] && printf 'true' || printf 'false' )" \
          --arg ture "$TURE" \
          --arg max_tokens "$MAX_TOKENS" \
          --arg user "$CONTENT" \
          '{model:$model, stream:$stream, temperature:($ture|tonumber), max_tokens:($max_tokens|tonumber), messages:[{role:"user",content:$user}] }' >"$tmp_payload"
  fi
  mv "$tmp_payload" "$PAYLOAD" 2>/dev/null || cp -f "$tmp_payload" "$PAYLOAD" 2>/dev/null || true
  chmod 600 "$PAYLOAD" 2>/dev/null || true
  return 0
}

callapigemini() {
  if [ -z "${GEMINIAPIKEY:-}" ]; then echo "Error: GEMINIAPIKEY is not set." >&2; return $GROQBASHERRNOAPIKEY; fi
  if [ ! -s "${PAYLOAD:-}" ]; then echo "Error: payload file missing or empty: ${PAYLOAD:-<unset>}" >&2; return $GROQBASHERRTMP; fi
  if [ "${DRY_RUN:-0}" -eq 1 ]; then printf 'DRY-RUN: skipping HTTP call (exit 0)\n' >&2; return 0; fi

  local workdir tmpout api_url http_code time_total
  workdir="$(_get_work_tmpdir_gemini)" || return $GROQBASHERRTMP
  tmpout="$(_mktemp_in_dir_gemini "$workdir")" || return $GROQBASHERRTMP
  api_url="https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
  curl "${CURL_BASE_OPTS[@]}" -H "Authorization: Bearer $GEMINIAPIKEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" -o "$RESP" -w '%{http_code} %{time_total}' "$api_url" 2>"$ERRF" >"$tmpout" || true
  read -r http_code time_total < "$tmpout" 2>/dev/null || { http_code="$(cat "$tmpout" 2>/dev/null || echo "000")"; time_total="0"; }
  rm -f "$tmpout" 2>/dev/null || true
  case "$http_code" in 2*) return 0 ;; *) dbg "HTTP error code: $http_code"; dbg "Response (head):"; head -n 200 "$RESP" >&2 || true; dbg "Curl stderr (head):"; head -n 200 "$ERRF" >&2 || true; return $GROQBASHERRAPI ;; esac
}

callapistreaming_gemini() {
  if [ -z "${GEMINIAPIKEY:-}" ]; then echo "Error: GEMINIAPIKEY is not set." >&2; return $GROQBASHERRNOAPIKEY; fi
  if [ "${DRY_RUN:-0}" -eq 1 ]; then printf 'DRY-RUN: skipping streaming HTTP call (exit 0)\n' >&2; return 0; fi

  local api_url rc
  api_url="https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
  curl "${CURL_BASE_OPTS[@]}" -H "Authorization: Bearer $GEMINIAPIKEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" "$api_url" 2>"$ERRF" | tee "$RESP" | \
  while IFS= read -r line; do
    case "$line" in
      'data: [DONE]'|'data:[DONE]') break ;;
      data:\ * )
        json="${line#data: }"
        raw="$(printf '%s' "$json" | jq -R -c 'fromjson? | (.choices[]?.delta?.content // .choices[]?.message?.content // empty) | select(length>0)' 2>>"$ERRF" || true)"
        if [ -n "$raw" ]; then
          printf '%s' "$raw"
        fi
        ;;
      *) ;;
    esac
  done
  rc=${PIPESTATUS[0]:-0}
  [ "$rc" -ne 0 ] && { dbg "curl stderr (head):"; head -n 50 "$ERRF" >&2 || true; return $GROQBASHERRCURL_FAILED; }
  return 0
}

refreshmodelsgemini() {
  if [ -z "${GEMINIAPIKEY:-}" ]; then echo "Error: GEMINIAPIKEY is required to refresh models." >&2; return $GROQBASHERRNOAPIKEY; fi
  local workdir tmpd out errf parsed tmpout api_url
  workdir="$(_get_work_tmpdir_gemini)" || return $GROQBASHERRTMP
  tmpd="$(mktemp -d -p "$workdir" gemini-models.XXXX 2>/dev/null || true)"
  [ -z "$tmpd" ] && return $GROQBASHERRTMP
  out="$tmpd/models.json"
  errf="$tmpd/curl.err"
  api_url="https://generativelanguage.googleapis.com/v1beta/models"
  if ! curl "${CURL_BASE_OPTS[@]}" -H "Authorization: Bearer $GEMINIAPIKEY" -H "Content-Type: application/json" "$api_url" -o "$out" 2>"$errf"; then
    dbg "curl stderr:"; head -n 50 "$errf" >&2 || true
    rm -rf "$tmpd"
    return $GROQBASHERRCURL_FAILED
  fi
  parsed="$tmpd/parsed_models.txt"
  jq -r '.models[]?.name // empty' "$out" | sort -u > "$parsed" || true
  if [ -s "$parsed" ]; then
    mkdir -p "$(dirname "$MODELS_FILE")" 2>/dev/null || true
    tmpout="$(_mktemp_in_dir_gemini "$(dirname "$MODELS_FILE")" )" || tmpout="$MODELS_FILE.tmp"
    cat "$parsed" > "$tmpout"
    mv "$tmpout" "$MODELS_FILE" 2>/dev/null || cp -f "$tmpout" "$MODELS_FILE" 2>/dev/null || true
    chmod 600 "$MODELS_FILE" 2>/dev/null || true
    rm -rf "$tmpd"
    return 0
  else
    dbg "Raw response (head):"; head -n 50 "$out" >&2 || true
    rm -rf "$tmpd"
    return $GROQBASHERRAPI
  fi
}

validatemodelgemini() {
  local model="$1"
  if [ -f "$MODELS_FILE" ] && [ -s "$MODELS_FILE" ]; then
    grep -x -F -q "$model" "$MODELS_FILE" 2>/dev/null
    return $?
  fi
  return 0
}

autoselectmodelgemini() {
  local file="$MODELS_FILE" result=""
  if [ -f "$file" ] && [ -s "$file" ]; then
    result="$(awk 'NF{print; exit}' "$file" 2>/dev/null || true)"
    printf '%s' "$result"
    return 0
  fi
  printf ''
  return 0
}
