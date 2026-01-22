#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/security/validate-env.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
#
# Validate environment and directory configuration for GroqBash.
# Prints human-readable report and exits non-zero on critical failures.
#
set -euo pipefail

_ok() { printf 'OK: %s\n' "$*"; }
_warn() { printf 'WARN: %s\n' "$*"; }
_err() { printf 'ERROR: %s\n' "$*"; }

# Helpers
_is_world_writable() {
  local d="$1" perms others_write
  [ -d "$d" ] || return 1
  perms="$(ls -ld "$d" 2>/dev/null | awk '{print $1}' 2>/dev/null || true)"
  [ -z "$perms" ] && return 1
  others_write="$(printf '%s' "$perms" | awk '{print substr($0,9,1)}')"
  [ "$others_write" = "w" ]
}

# Determine env vars (support both naming variants)
GROQBASH_TMPDIR="${GROQBASH_TMPDIR:-${GROQBASHTMPDIR:-}}"
GROQBASH_EXTRAS_DIR="${GROQBASH_EXTRAS_DIR:-${GROQBASHEXTRASDIR:-}}"

critical_fail=0

printf 'Checking required tools...\n'
required_tools="bash curl mktemp awk sed grep"
for t in $required_tools; do
  if command -v "$t" >/dev/null 2>&1; then
    _ok "Found required tool: $t"
  else
    _err "Missing required tool: $t"
    critical_fail=1
  fi
done

printf '\nChecking recommended tools...\n'
recommended_tools="jq python3"
for t in $recommended_tools; do
  if command -v "$t" >/dev/null 2>&1; then
    _ok "Recommended tool available: $t"
  else
    _warn "Recommended tool not found: $t"
  fi
done

printf '\nValidating GROQBASH_TMPDIR...\n'
if [ -z "${GROQBASH_TMPDIR:-}" ]; then
  _warn "GROQBASH_TMPDIR is not set. GroqBash will use its default internal tmpdir."
else
  case "$GROQBASH_TMPDIR" in
    /*) : ;;
    *)
      _err "GROQBASH_TMPDIR must be an absolute path: $GROQBASH_TMPDIR"
      critical_fail=1
      ;;
  esac
  if [ -n "$GROQBASH_TMPDIR" ]; then
    if [ -d "$GROQBASH_TMPDIR" ]; then
      if _is_world_writable "$GROQBASH_TMPDIR"; then
        _err "GROQBASH_TMPDIR is world-writable: $GROQBASH_TMPDIR"
        critical_fail=1
      else
        _ok "GROQBASH_TMPDIR exists and is not world-writable: $GROQBASH_TMPDIR"
      fi
    else
      # Try to create a temp dir under it to test creatability
      if mkdir -p "$GROQBASH_TMPDIR" 2>/dev/null; then
        _ok "GROQBASH_TMPDIR created: $GROQBASH_TMPDIR"
        # revert creation if empty? leave as is; it's user-specified
      else
        _err "GROQBASH_TMPDIR does not exist and cannot be created: $GROQBASH_TMPDIR"
        critical_fail=1
      fi
    fi
  fi
fi

printf '\nValidating GROQBASH_EXTRAS_DIR...\n'
if [ -z "${GROQBASH_EXTRAS_DIR:-}" ]; then
  _err "GROQBASH_EXTRAS_DIR is not set. Set it to your groqbash extras directory."
  critical_fail=1
else
  case "$GROQBASH_EXTRAS_DIR" in
    /*) : ;;
    *)
      _err "GROQBASH_EXTRAS_DIR must be an absolute path: $GROQBASH_EXTRAS_DIR"
      critical_fail=1
      ;;
  esac
  if [ -n "$GROQBASH_EXTRAS_DIR" ]; then
    if [ -d "$GROQBASH_EXTRAS_DIR" ]; then
      if _is_world_writable "$GROQBASH_EXTRAS_DIR"; then
        _err "GROQBASH_EXTRAS_DIR is world-writable: $GROQBASH_EXTRAS_DIR"
        critical_fail=1
      else
        _ok "GROQBASH_EXTRAS_DIR exists and is not world-writable: $GROQBASH_EXTRAS_DIR"
      fi
    else
      if mkdir -p "$GROQBASH_EXTRAS_DIR" 2>/dev/null; then
        _ok "GROQBASH_EXTRAS_DIR created: $GROQBASH_EXTRAS_DIR"
      else
        _err "GROQBASH_EXTRAS_DIR does not exist and cannot be created: $GROQBASH_EXTRAS_DIR"
        critical_fail=1
      fi
    fi
  fi
fi

printf '\nSummary:\n'
if [ "$critical_fail" -ne 0 ]; then
  _err "One or more critical checks failed. Fix the issues above before running groqbash in untrusted environments."
  exit 2
else
  _ok "All critical environment checks passed."
  exit 0
fi
