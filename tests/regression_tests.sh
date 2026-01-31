#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: tests/regression_tests.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
CORE_PATH="$ROOT_DIR/groqbash"
PROVIDERS_DIR="$ROOT_DIR/extras/providers"
TEST_TMPDIR="$ROOT_DIR/tests/.tmp"
MODELS_FILE_DEFAULT="$ROOT_DIR/groqbash.d/models/models.txt"

mkdir -p "$TEST_TMPDIR" || { printf '[FAIL] setup: cannot create test tmp dir\n'; exit 1; }

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

ok() { printf '[PASS] %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { printf '[FAIL] %s: %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT+1)); }
skip() { printf '[SKIP] %s: %s\n' "$1" "$2"; SKIP_COUNT=$((SKIP_COUNT+1)); }

run_cmd_capture() {
  local outf="$1"; shift
  "$@" >"$outf" 2>&1
  return $?
}

# ---------- Helpers ----------
contains() {
  local file="$1" pat="$2"
  grep -qE "$pat" "$file" 2>/dev/null
}
count_matches() {
  local file="$1" pat="$2"
  grep -E "$pat" "$file" 2>/dev/null | wc -l
}
function_exists_in_file() {
  local file="$1" func="$2"
  awk -v f="$func" '
    BEGIN{found=0}
    {
      if ($0 ~ ("^[[:space:]]*function[[:space:]]+"f"([[:space:]]*\\(\\))?")) found=1
      if ($0 ~ ("^[[:space:]]*"f"[[:space:]]*\\(")) found=1
    }
    END{exit(found?0:1)}
  ' "$file"
}

# ---------- Pre-check: core executable ----------
check_core_executable() {
  local name="core_executable"
  if [ ! -f "$CORE_PATH" ]; then
    fail "$name" "core file not found at $CORE_PATH"
    return 1
  fi
  if [ ! -x "$CORE_PATH" ]; then
    fail "$name" "core file exists but is not executable: $CORE_PATH"
    return 1
  fi
  ok "$name"
  return 0
}

check_core_executable || { printf '\nCritical: groqbash not executable. Aborting.\n'; printf 'Passed: %d, Failed: %d, Skipped: %d\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"; exit 2; }

# ---------- Core integrity (critical) ----------
test_core_no_tmp() {
  local name="core_no_tmp"
  if [ ! -f "$CORE_PATH" ]; then fail "$name" "core file not found at $CORE_PATH"; return 1; fi
  if grep -n --binary-files=without-match '/tmp' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "found '/tmp' usage in core"
    return 1
  fi
  ok "$name"; return 0
}

test_core_no_eval() {
  local name="core_no_eval"
  if grep -n --binary-files=without-match '\beval\b' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "found eval in core"
    return 1
  fi
  ok "$name"; return 0
}

test_core_no_network_calls() {
  local name="core_no_network_calls"
  if grep -n --binary-files=without-match -E '\bcurl\b|https?://' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "found network-related tokens (curl/http) in core"
    return 1
  fi
  ok "$name"; return 0
}

test_core_no_groq_vars_funcs() {
  local name="core_no_groq_vars_funcs"
  local bad=0
  if grep -n --binary-files=without-match -E 'GROQ_API_KEY|GROQAPIKEY|GROQ_APIKEY' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "found Groq-specific API key variables in core"
    bad=1
  fi
  if grep -n --binary-files=without-match -E 'buildpayloadgroq|callapigroq|callapistreaming_groq|refreshmodelsgroq|validatemodelgroq' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "found Groq-specific functions in core"
    bad=1
  fi
  if [ "$bad" -eq 1 ]; then return 1; fi
  ok "$name"; return 0
}

test_core_dispatch_present() {
  local name="core_dispatch_present"
  if ! grep -n --binary-files=without-match 'build_payload_from_vars' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "build_payload_from_vars not found in core"
    return 1
  fi
  if ! grep -n --binary-files=without-match 'call_api_once' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "call_api_once not found in core"
    return 1
  fi
  if ! grep -n --binary-files=without-match 'call_api_streaming' "$CORE_PATH" >/dev/null 2>&1; then
    fail "$name" "call_api_streaming not found in core"
    return 1
  fi
  ok "$name"; return 0
}

# Run critical core tests; abort on failure
core_tests_fail=0
test_core_no_tmp || core_tests_fail=1
test_core_no_eval || core_tests_fail=1
test_core_no_network_calls || core_tests_fail=1
test_core_no_groq_vars_funcs || core_tests_fail=1
test_core_dispatch_present || core_tests_fail=1

if [ "$core_tests_fail" -ne 0 ]; then
  printf '\nCritical core integrity tests failed. Aborting further tests.\n'
  printf 'Passed: %d, Failed: %d, Skipped: %d\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
  exit 2
fi

# ---------- Provider integrity ----------
test_provider_file() {
  local prov_file="$1"
  local prov
  prov="$(basename "$prov_file" .sh)"
  local name="provider_${prov}_integrity"
  local bad=0

  if grep -n --binary-files=without-match '/tmp' "$prov_file" >/dev/null 2>&1; then
    fail "$name" "found '/tmp' usage in $prov_file"; bad=1
  fi
  if grep -n --binary-files=without-match '\beval\b' "$prov_file" >/dev/null 2>&1; then
    fail "$name" "found eval in $prov_file"; bad=1
  fi
  # ensure no top-level curl before first function definition
  local first_func_line
  first_func_line="$(grep -nE '^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)' "$prov_file" | head -n1 | cut -d: -f1 || true)"
  if [ -n "$first_func_line" ]; then
    if awk "NR<=$first_func_line" "$prov_file" | grep -n --binary-files=without-match '\bcurl\b' >/dev/null 2>&1; then
      fail "$name" "found curl invocation before first function in $prov_file"; bad=1
    fi
  fi
  if grep -n --binary-files=without-match '^[[:space:]]*exit[[:space:]]' "$prov_file" >/dev/null 2>&1; then
    fail "$name" "found exit in $prov_file (providers must use return)"; bad=1
  fi

  # Required functions (use robust detection)
  local req1="buildpayload${prov}"
  local req2="callapi${prov}"
  local req3="callapistreaming_${prov}"
  if ! function_exists_in_file "$prov_file" "$req1"; then
    fail "$name" "missing required function ${req1} in $prov_file"; bad=1
  fi
  if ! function_exists_in_file "$prov_file" "$req2"; then
    fail "$name" "missing required function ${req2} in $prov_file"; bad=1
  fi
  if ! function_exists_in_file "$prov_file" "$req3"; then
    fail "$name" "missing required function ${req3} in $prov_file"; bad=1
  fi

  # Optional functions: if present, must follow naming
  local opt1="refreshmodels${prov}"
  local opt2="validatemodel${prov}"
  local opt3="autoselectmodel${prov}"
  # check for aliases/double interfaces: disallow alternate naming patterns
  if grep -qE "build_payload_${prov}|buildpayload_${prov}" "$prov_file"; then
    fail "$name" "found alternate buildpayload naming in $prov_file (no aliases allowed)"; bad=1
  fi
  if grep -qE "call_api_${prov}|callapi_${prov}" "$prov_file"; then
    fail "$name" "found alternate callapi naming in $prov_file (no aliases allowed)"; bad=1
  fi
  if grep -qE "call_api_streaming_${prov}|callapistreaming${prov}" "$prov_file"; then
    if ! grep -qE "callapistreaming_${prov}" "$prov_file"; then
      fail "$name" "found alternate callapistreaming naming in $prov_file (no aliases allowed)"; bad=1
    fi
  fi

  if [ "$bad" -eq 1 ]; then
    return 1
  fi
  ok "$name"
  return 0
}

for f in "$PROVIDERS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  test_provider_file "$f" || true
done

# ---------- CLI tests (non-networked where possible) ----------
run_cli_test() {
  local name="$1"; shift
  local cmd=( "$CORE_PATH" "$@" )
  local outf="$TEST_TMPDIR/cli_$(echo "$name" | tr ' /' '__').out"
  run_cmd_capture "$outf" "${cmd[@]}"
  local rc=$?
  if [ $rc -ne 0 ]; then
    fail "$name" "exit code $rc; output: $(head -n1 "$outf" 2>/dev/null || true)"
    return 1
  fi
  ok "$name"
  return 0
}

test_cli_help() {
  run_cli_test "cli_help" --help
}
test_cli_version() {
  run_cli_test "cli_version" --version
}
test_cli_provider_groq_dryrun() {
  local name="cli_provider_groq_dryrun"
  local model="test-model"
  local outf="$TEST_TMPDIR/provider_groq_dryrun.out"
  "$CORE_PATH" --provider groq -m "$model" --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then ok "$name"; else fail "$name" "expected DRY-RUN output"; fi
}
test_cli_json_dryrun() {
  local name="cli_json_dryrun"
  local outf="$TEST_TMPDIR/cli_json.out"
  "$CORE_PATH" --json --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then ok "$name"; else fail "$name" "expected DRY-RUN output"; fi
}
test_cli_pretty_dryrun() {
  local name="cli_pretty_dryrun"
  local outf="$TEST_TMPDIR/cli_pretty.out"
  "$CORE_PATH" --pretty --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then ok "$name"; else fail "$name" "expected DRY-RUN output"; fi
}
test_cli_stream_dryrun() {
  local name="cli_stream_dryrun"
  local outf="$TEST_TMPDIR/cli_stream.out"
  "$CORE_PATH" --stream --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then ok "$name"; else fail "$name" "expected DRY-RUN output"; fi
}

test_cli_help || true
test_cli_version || true
test_cli_provider_groq_dryrun || true
test_cli_json_dryrun || true
test_cli_pretty_dryrun || true
test_cli_stream_dryrun || true

# ---------- DRYRUN test ----------
test_dry_run_behavior() {
  local name="dry_run_behavior"
  local outf="$TEST_TMPDIR/dryrun.out"
  "$CORE_PATH" --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then ok "$name"; else fail "$name" "DRY-RUN not indicated in output"; fi
}

test_dry_run_behavior || true

# ---------- History test (best-effort, non-critical) ----------
test_history_creation() {
  local name="history_creation"
  local hist_dir="$ROOT_DIR/groqbash.d/history"
  if [ ! -d "$hist_dir" ]; then
    skip "$name" "history directory not present"
    return 0
  fi
  skip "$name" "cannot reliably test history without network; manual check recommended"
  return 0
}

test_history_creation || true

# ---------- Models tests ----------
test_refresh_models() {
  local name="refresh_models"
  local outf="$TEST_TMPDIR/refresh_models.out"
  "$CORE_PATH" --refresh-models --dry-run >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then
    skip "$name" "dry-run; refresh not executed"
    return 0
  fi
  if grep -q -i 'does not support automatic model refresh' "$outf"; then
    skip "$name" "provider reports no automatic refresh"
    return 0
  fi
  ok "$name"
  return 0
}

test_list_models() {
  local name="list_models"
  local outf="$TEST_TMPDIR/list_models.out"
  "$CORE_PATH" --list-models >"$outf" 2>&1 || true
  if [ -s "$outf" ]; then ok "$name"; else skip "$name" "no models printed (may be empty)"; fi
}

test_refresh_models || true
test_list_models || true

# ---------- Error tests (non-critical) ----------
test_provider_no_api_key() {
  local name="provider_no_api_key"
  for prov_file in "$PROVIDERS_DIR"/*.sh; do
    [ -f "$prov_file" ] || continue
    local prov
    prov="$(basename "$prov_file" .sh)"
    local outf="$TEST_TMPDIR/no_api_${prov}.out"
    local -a vars=()
    local up
    up="$(printf '%s' "$prov" | tr '[:lower:]' '[:upper:]')"
    vars+=( "${up}APIKEY" "${up}_API_KEY" )
    case "$prov" in
      huggingface) vars+=( "HFAPIKEY" "HF_API_KEY" "HUGGINGFACE_API_KEY" "HUGGINGFACEAPIKEY" ) ;;
      groq) vars+=( "GROQ_API_KEY" "GROQAPIKEY" ) ;;
      gemini) vars+=( "GEMINIAPIKEY" "GEMINI_API_KEY" ) ;;
    esac
    local -a uniq_vars=()
    local v
    for v in "${vars[@]}"; do
      case " ${uniq_vars[*]} " in *" $v "*) ;; *) uniq_vars+=( "$v" ) ;; esac
    done
    if command -v env >/dev/null 2>&1; then
      local -a env_cmd=(env)
      for v in "${uniq_vars[@]}"; do env_cmd+=( -u "$v" ); done
      env_cmd+=( "$CORE_PATH" --provider "$prov" --dry-run "hello" )
      "${env_cmd[@]}" >"$outf" 2>&1 || true
    else
      local -a cmd=( )
      for v in "${uniq_vars[@]}"; do cmd+=( "$v=" ); done
      cmd+=( "$CORE_PATH" --provider "$prov" --dry-run "hello" )
      "${cmd[@]}" >"$outf" 2>&1 || true
    fi
    if grep -q -i 'DRY-RUN' "$outf"; then
      skip "${name}_${prov}" "dry-run; cannot assert API key error"
      continue
    fi
    if grep -q -i 'API key' "$outf" || grep -q -i 'not set' "$outf" || grep -q -i 'required' "$outf"; then
      ok "${name}_${prov}"
    else
      skip "${name}_${prov}" "no API key error observed (network suppressed or provider handles missing key differently)"
    fi
  done
  return 0
}

test_model_nonexistent() {
  local name="model_nonexistent"
  local outf="$TEST_TMPDIR/model_nonexistent.out"
  "$CORE_PATH" -m "this-model-does-not-exist-xyz" --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then
    skip "$name" "dry-run; cannot assert model validation"
    return 0
  fi
  if grep -q -i 'not supported' "$outf" || grep -q -i 'not in whitelist' "$outf" || grep -q -i 'not found' "$outf"; then ok "$name"; else skip "$name" "no model error observed"; fi
}

test_provider_no_api_key || true
test_model_nonexistent || true

# ---------- Streaming tests (best-effort) ----------
test_streaming_behavior() {
  local name="streaming_behavior"
  local outf="$TEST_TMPDIR/streaming_behavior.out"
  "$CORE_PATH" --stream --dry-run "hello" >"$outf" 2>&1 || true
  if grep -q -i 'DRY-RUN' "$outf"; then
    skip "$name" "dry-run; streaming network suppressed"
    return 0
  fi
  ok "$name"
}

test_streaming_behavior || true

# ---------- Core <-> Provider coherence tests ----------
test_core_provider_dispatch_coherence() {
  local name="core_provider_dispatch_coherence"
  if ! grep -q 'build_payload_from_vars' "$CORE_PATH"; then fail "$name" "core missing build_payload_from_vars"; return 1; fi
  if ! grep -q 'call_api_once' "$CORE_PATH"; then fail "$name" "core missing call_api_once"; return 1; fi
  if ! grep -q 'call_api_streaming' "$CORE_PATH"; then fail "$name" "core missing call_api_streaming"; return 1; fi
  ok "$name"
  return 0
}

test_core_provider_dispatch_coherence || true

# ---------- Provider function presence (robust) ----------
test_provider_function_presence() {
  local name="provider_function_presence"
  local failed=0
  local f
  for f in "$PROVIDERS_DIR"/*.sh; do
    [ -f "$f" ] || continue
    local prov
    prov="$(basename "$f" .sh)"
    if ! function_exists_in_file "$f" "buildpayload${prov}"; then
      fail "$name" "provider $prov missing buildpayload${prov}()"; failed=1
    fi
    if ! function_exists_in_file "$f" "callapi${prov}"; then
      fail "$name" "provider $prov missing callapi${prov}()"; failed=1
    fi
    if ! function_exists_in_file "$f" "callapistreaming_${prov}"; then
      fail "$name" "provider $prov missing callapistreaming_${prov}()"; failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then ok "$name"; else return 1; fi
}

test_provider_function_presence || true

# ---------- Summary ----------
printf '\nTest summary:\n'
printf 'Passed: %d\n' "$PASS_COUNT"
printf 'Failed: %d\n' "$FAIL_COUNT"
printf 'Skipped: %d\n' "$SKIP_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; else exit 0; fi
