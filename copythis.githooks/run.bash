# run.bash is a generic hook handler.
# This file is sourced by every hook installed in .git/hooks/, its main job is to
# find and run all the handlers for the HOOK_NAME hook, passing through any
# arguments from Git itself.

set -euo pipefail

# debug prints a debug message iff DEBUG=YES.
debug() { if [ "${DEBUG:-}" != "YES" ]; then return; fi; echo "==> DEBUG: $1" 1>&2; }

# die prints an error message and then exits with the supplied exit code (defaults to 1).
die() { echo "==> ERROR: Commit cancelled: $1" 1>&2; exit "${2:-1}"; }

RAN_HANDLERS=

handle_exit() {
  debug "Ran ${#RAN_HANDLERS} $HOOK_NAME handlers: $RAN_HANDLERS"
}

trap handle_exit EXIT

# Get the path to each handler for this hook, sorted by name.
HANDLERS="$(find ".githooks/$HOOK_NAME" -type f | sort)"

debug "Found ${#HANDLERS} $HOOK_NAME handlers: $HANDLERS"

# Try to execute each hook in order, exit on the first failure.
for H in $HANDLERS; do
  debug "Running git $HOOK_NAME hook handler: $H"
  [ -x "$H" ] || die "git $HOOK_NAME hook handler not executable: $H"
  RAN_HANDLERS="$(basename "$H")"
  "./$H" "$@" || die "git $HOOK_NAME hook handler failed: $H" $?
done

