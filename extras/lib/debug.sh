#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/lib/debug.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
# Purpose: Optional debug and diagnostics helpers for groqbash.
# Source this file to enable richer diagnostics. The core does not require it.
#
# Usage (optional):
#   . /path/to/groqbash.d/extras/lib/debug.sh
#
# This file intentionally avoids side effects on load.

[ -n "${GROQBASH_DEBUG_SH_LOADED:-}" ] && return 0
GROQBASH_DEBUG_SH_LOADED=1

# verbose_log: controlled verbose logging
# Usage: verbose_log "some message"
verbose_log() {
  local level="${1:-INFO}"; shift
  # Only print if DEBUG is set (core uses DEBUG=1 for debug mode)
  [ "${DEBUG:-0}" -eq 1 ] || return 0
  printf '[%s] %s\n' "$level" "$*" >&2
}

# dump_state: print a compact snapshot of important variables
# Usage: dump_state
dump_state() {
  cat <<'STATE' >&2
=== groqbash state dump ===
STATE
  printf 'PROVIDER=%s\n' "${PROVIDER:-}" >&2
  printf 'MODEL=%s\n' "${MODEL:-}" >&2
  printf 'STREAM_MODE=%s\n' "${STREAM_MODE:-}" >&2
  printf 'OUTPUT_MODE=%s\n' "${OUTPUT_MODE:-}" >&2
  printf 'GROQ_API_KEY set? %s\n' "[ -n \"${GROQ_API_KEY:-}\" ] && echo yes || echo no" | sh -s 2>/dev/null || true
  printf 'GROQBASH_CONFIG_DIR=%s\n' "${GROQBASH_CONFIG_DIR:-}" >&2
  printf 'GROQBASH_MODELS_DIR=%s\n' "${GROQBASH_MODELS_DIR:-}" >&2
  printf 'GROQBASH_TMPDIR=%s\n' "${GROQBASH_TMPDIR:-}" >&2
  printf 'ALLOWED_MODELS present? %s\n' "[ -n \"${ALLOWED_MODELS:-}\" ] && echo yes || echo no" | sh -s 2>/dev/null || true
  printf '============================\n' >&2
}

# print_env_subset: print selected environment variables useful for debugging
# Usage: print_env_subset GROQ_API_KEY GROQ_MODEL OTHER_VAR
print_env_subset() {
  local var
  for var in "$@"; do
    printf '%s=%s\n' "$var" "${!var:-}" >&2
  done
}

# structured_debug: print a key:value list in aligned columns
# Usage: structured_debug key1 "value1" key2 "value2" ...
structured_debug() {
  local -a pairs=("$@")
  local i key val max=0
  for ((i=0;i<${#pairs[@]};i+=2)); do
    key="${pairs[i]}"
    [ "${#key}" -gt "$max" ] && max="${#key}"
  done
  for ((i=0;i<${#pairs[@]};i+=2)); do
    key="${pairs[i]}"; val="${pairs[i+1]:-}"
    printf '%-*s : %s\n' "$max" "$key" "$val" >&2
  done
}

# trace_cmd: run a command and print it before execution (debug only)
# Usage: trace_cmd ls -la /tmp
trace_cmd() {
  [ "${DEBUG:-0}" -eq 1 ] || { "$@"; return $?; }
  printf '[TRACE] %s\n' "$*" >&2
  "$@"
}

# safe_dump_file_head: print head of a file for quick inspection
safe_dump_file_head() {
  local f="$1" n="${2:-20}"
  if [ -r "$f" ]; then
    printf '--- head of %s (first %s lines) ---\n' "$f" "$n" >&2
    head -n "$n" "$f" >&2 || true
    printf '--- end ---\n' >&2
  else
    printf 'File not readable: %s\n' "$f" >&2
  fi
}

# End of extras/lib/debug.sh
