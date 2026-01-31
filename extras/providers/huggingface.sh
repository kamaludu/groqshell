#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/providers/huggingface.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
set -euo pipefail

HFAPIKEY="${HFAPIKEY:-}"

_get_work_tmpdir_hf() {
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

_mktemp_in_dir_hf() {
  local dir="$1" tmpf
  [ -z "$dir" ] && return 1
  [ ! -d "$dir" ] && return 1
  tmpf="$(mktemp -p "$dir" hf-XXXX 2>/dev/null || true)"
  [ -z "$tmpf" ] && return 1
  printf '%s' "$tmpf"
  return 0
}

buildpayloadhuggingface() {
  local workdir tmp_payload model_in_file model_to_use user_prompt
  workdir="$(_get_work_tmpdir_hf)" || return $GROQBASHERRTMP
  tmp_payload="$(_mktemp_in_dir_hf "$workdir")" || return $GROQBASHERRTMP
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

callapihuggingface() {
  if [ -z "${HFAPIKEY:-}" ]; then echo "Error: HFAPIKEY is not set." >&2; return $GROQBASHERRNOAPIKEY; fi
  if [ ! -s "${PAYLOAD:-}" ]; then echo "Error: payload file missing or empty: ${PAYLOAD:-<unset>}" >&2; return $GROQBASHERRTMP; fi
  if [ "${DRY_RUN:-0}" -eq 1 ]; then printf 'DRY-RUN: skipping HTTP call (exit 0)\n' >&2; return 0; fi

  local workdir tmpout api_url http_code time_total
  workdir="$(_get_work_tmpdir_hf)" || return $GROQBASHERRTMP
  tmpout="$(_mktemp_in_dir_hf "$workdir")" || return $GROQBASHERRTMP
  api_url="https://api-inference.huggingface.co/v1/chat/completions"
  curl "${CURL_BASE_OPTS[@]}" -H "Authorization: Bearer $HFAPIKEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" -o "$RESP" -w '%{http_code} %{time_total}' "$api_url" 2>"$ERRF" >"$tmpout" || true
  read -r http_code time_total < "$tmpout" 2>/dev/null || { http_code="$(cat "$tmpout" 2>/dev/null || echo "000")"; time_total="0"; }
  rm -f "$tmpout" 2>/dev/null || true
  case "$http_code" in 2*) return 0 ;; *) dbg "HTTP error code: $http_code"; dbg "Response (head):"; head -n 200 "$RESP" >&2 || true; dbg "Curl stderr (head):"; head -n 200 "$ERRF" >&2 || true; return $GROQBASHERRAPI ;; esac
}

callapistreaming_huggingface() {
  if [ -z "${HFAPIKEY:-}" ]; then echo "Error: HFAPIKEY is not set." >&2; return $GROQBASHERRNOAPIKEY; fi
  if [ "${DRY_RUN:-0}" -eq 1 ]; then printf 'DRY-RUN: skipping streaming HTTP call (exit 0)\n' >&2; return 0; fi

  local api_url rc
  api_url="https://api-inference.huggingface.co/v1/chat/completions"
  curl "${CURL_BASE_OPTS[@]}" -H "Authorization: Bearer $HFAPIKEY" -H "Content-Type: application/json" --data-binary @"$PAYLOAD" "$api_url" 2>"$ERRF" | tee "$RESP" | \
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

refreshmodelshuggingface() {
  local outpath="${1:-$MODELS_FILE}"
  if [ -f "$MODELS_FILE" ] && [ -s "$MODELS_FILE" ]; then
    mkdir -p "$(dirname "$outpath")" 2>/dev/null || true
    cp -f "$MODELS_FILE" "$outpath" 2>/dev/null || { echo "Error: cannot copy models file." >&2; return 1; }
    chmod 600 "$outpath" 2>/dev/null || true
    echo "Model list copied from local MODELS_FILE to $outpath" >&2
    return 0
  fi
  echo "Hugging Face does not support automatic model refresh" >&2
  return 1
}

validatemodelhuggingface() {
  local model="$1"
  if [ -f "$MODELS_FILE" ] && [ -s "$MODELS_FILE" ]; then
    grep -x -F -q "$model" "$MODELS_FILE" 2>/dev/null
    return $?
  fi
  return 0
}

autoselectmodelhuggingface() {
  local file="$MODELS_FILE" result=""
  if [ -f "$file" ] && [ -s "$file" ]; then
    result="$(awk 'NF{print; exit}' "$file" 2>/dev/null || true)"
    printf '%s' "$result"
    return 0
  fi
  printf ''
  return 0
}
