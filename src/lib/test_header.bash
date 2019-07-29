# test_header.bash should be sourced at the beginning of every test file.
# It detects the name of the file under test, and defines some functions
# for use in running that script and making assertions on its output.

DEBUG="${DEBUG:-}"
RUN="${RUN:-}"
export INDENT="${INDENT:-}"

set -euo pipefail

# Determine SCRIPT_NAME to test (this file name with .test suffix removed).
SCRIPT_NAME=${0%.test}
SCRIPT_NAME=${SCRIPT_NAME#./}
SCRIPT_FILE=$PWD/$SCRIPT_NAME.bash
METADATA="$PWD/.testdata/$SCRIPT_NAME"
mkdir -p "$METADATA"
RUN_COUNT_FILE="$METADATA/count-run"
FAIL_COUNT_FILE="$METADATA/count-fail"
rm -f "$RUN_COUNT_FILE"
rm -f "$FAIL_COUNT_FILE"
export SCRIPT_NAME SCRIPT_FILE METADATA RUN_COUNT_FILE FAIL_COUNT_FILE

# shellcheck disable=SC2059 # We need to use a variable as the format arg to printf.
putf()  {
  FMT="$1"; shift;
  printf -- "$FMT\n" "$@" | sed "s/^/$INDENT/" 1>&2
}
log() {
  [ "$DEBUG" == YES ] || return 0
  FMT="$1"; shift; putf "--> INFO: $FMT" "$@";
}
error() { FMT="$1"; shift; putf "--> ERROR: $FMT" "$@"; add_error; }
fatal() { FMT="$1"; shift; putf "--> FATAL: $FMT" "$@"; add_error; exit 1; }

trap print_summary EXIT

print_summary() {
  local RUN_COUNT FAIL_COUNT
  RUN_COUNT="$(cat "$RUN_COUNT_FILE" 2> /dev/null || echo 0)"

  [ "$RUN_COUNT" != 0 ] || {
    putf "==> No tests run for $SCRIPT_NAME"
    exit 0
  }

  FAIL_COUNT="$(cat "$FAIL_COUNT_FILE" 2> /dev/null || echo 0)"
  PASS_COUNT=$((RUN_COUNT - FAIL_COUNT))
  PASSFAIL=$([ "$FAIL_COUNT" = 0 ] && echo PASS || echo FAIL)
  FAILSUMMARY=$([ "$FAIL_COUNT" = 0 ] && echo "" || echo "; $FAIL_COUNT failed")
  putf "==> Summary %s %s %s/%s tests passed%s" \
    "$PASSFAIL" "$SCRIPT_NAME" "$PASS_COUNT" "$RUN_COUNT" "$FAILSUMMARY"
  [ "$FAIL_COUNT" = 0 ] || exit 1
}

match() {
  echo "$1" | grep -E "$2" > /dev/null 2>&1 || return 1
}

# begin_test sets TEST_NAME, TEST_ID, TESTDATA and BASH_ENV.
# TESTDATA is set to a directory path unique to this test, this directory
# is created, and we enter it prior to calling test_setup.
begin_test() {
  export TEST_NAME="$1"
  export TEST_ID="$SCRIPT_NAME/$TEST_NAME"
  # Do not run this test if RUN is set and does not match TEST_ID.
  [ -z "$RUN" ] || {
    match "$TEST_ID" "$RUN" || {
      log "Not running $TEST_ID: name does not match RUN='$RUN'"
      exit 0
    }
  }
  putf "==> Running test %s" "$TEST_ID"
  INDENT="  $INDENT"
  increment "$RUN_COUNT_FILE"
  export TESTDATA="$PWD/.testdata/$TEST_ID"
  export TEST_WORKDIR="$TESTDATA/work"
  rm -rf "$TESTDATA" "$TEST_WORKDIR"
  mkdir -p "$TESTDATA" "$TEST_WORKDIR"
  export SCRIPT_LOG="$TESTDATA/script.log"
  export ASSERTION_COUNT_FILE="$TESTDATA/count-assertions"
  export ERROR_COUNT_FILE="$TESTDATA/count-errors"
  rm -f "$ASSERTION_COUNT_FILE" "$ERROR_COUNT_FILE"
  cd "$TEST_WORKDIR"
  if command -v test_setup > /dev/null 2>&1; then
    test_setup
  fi
  trap handle_result EXIT
}

increment() {
  local C
  C="$(read_count "$1")"
  echo "$((C+1))" > "$1"
}

read_count() {
  cat "$1" 2> /dev/null || echo 0
}

# handle_result always exits with 0 so other tests can continue.
handle_result() {
  # assert the test exited cleanly to catch non-assert errors in the test.
  # || true because we still want to finish handling the test exit.
  assert "test exited cleanly" [ $? == 0 ] || true
  ERROR_COUNT="$(read_count "$ERROR_COUNT_FILE")"
  ASSERTION_COUNT="$(read_count "$ASSERTION_COUNT_FILE")"
  if [ "$ERROR_COUNT" = 0 ]; then
    log "OK: All $ASSERTION_COUNT assertions succeeded."
    exit 0
  fi
  error "$ERROR_COUNT/$ASSERTION_COUNT assertions failed, see output above."
  increment "$FAIL_COUNT_FILE"
  exit 0
}

# run_script runs the script under test using $TEST_SHELL.
# You may export a variable TEST_ENV, containing lines in the format
#   'export NAME=VALUE'
# in order to configure the environment for the script invocation.
#
# Parameters: none
# Input Variables:
#   TEST_SHELL: The shell to run this script using, e.g.:
#               '/usr/bin/env bash -euo pipefail -c'
#   TEST_ENV: List of export statements to run before the script.
#   TEST_WORKDIR: The working directory to run the script in (begin_test sets this).
#   SCRIPT_LOG: A file to log the script output (stdout+stderr) to.
#
run_script() {
  (
    set -euo pipefail
    log "PATH='$PATH'"
    log "TEST_ENV='$TEST_ENV'"
    eval "$TEST_ENV"
    cd "$WORKDIR"
    $TEST_SHELL "$(cat "$SCRIPT_FILE")" > "$SCRIPT_LOG" 2>&1
  )
}

run_script_require_success() {
  assert "script succeeds" run_script || {
    fatal "script failed; output: %s" "$(cat "$SCRIPT_LOG")"
  }
}

run_script_require_failure() {
  add_assertion
  if run_script; then
    fatal "script succeeded when it should have failed; output: %s" "$(cat "$SCRIPT_LOG")"
  fi
}

add_assertion() { increment "$ASSERTION_COUNT_FILE"; }
add_error() { increment "$ERROR_COUNT_FILE"; }

assert() {
  add_assertion
  WHAT="$1"; shift
  OUT="$("$@")" || {
    [ -n "$OUT" ] || OUT="<no output>"
    error "Asserting: %s\ncommand failed: %s:\n%s" "$WHAT" "$*" "$OUT" 
    return 1
  }
  log "Assert: %s" "$WHAT"
}

require() {
  assert "$@" || fatal "Last error was fatal; aborting test."
}

