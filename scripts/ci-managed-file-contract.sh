#!/bin/bash
# Contract test for profile::managed_file (simp/puppetsync#50):
#
#   - strategy => 'bootstrap' must NEVER overwrite an existing file
#     (this is the guarantee that keeps puppetsync from clobbering
#     Renovate-managed values)
#   - strategy => 'enforce' (and the default) must always overwrite
#   - both strategies must create a missing file with the given content
#
# Requires bolt (openbolt) and the project's modules (./Rakefile install).
set -euo pipefail
cd "$(dirname "$0")/.."

PUPPET="${PUPPET:-/opt/puppetlabs/bolt/bin/puppet}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
apply() { "$PUPPET" apply --modulepath modules:.modules -e "$1" >/dev/null; }

printf 'custom\n' > "$WORK/bootstrap-existing.txt"
apply "profile::managed_file { '$WORK/bootstrap-existing.txt': content => \"baseline\n\", strategy => 'bootstrap' }"
[ "$(cat "$WORK/bootstrap-existing.txt")" = 'custom' ] \
  || fail "strategy => bootstrap overwrote an existing file"

printf 'custom\n' > "$WORK/enforce-existing.txt"
apply "profile::managed_file { '$WORK/enforce-existing.txt': content => \"baseline\n\", strategy => 'enforce' }"
[ "$(cat "$WORK/enforce-existing.txt")" = 'baseline' ] \
  || fail "strategy => enforce did not overwrite an existing file"

printf 'custom\n' > "$WORK/default-existing.txt"
apply "profile::managed_file { '$WORK/default-existing.txt': content => \"baseline\n\" }"
[ "$(cat "$WORK/default-existing.txt")" = 'baseline' ] \
  || fail "the default strategy is not enforce"

apply "profile::managed_file { '$WORK/bootstrap-missing.txt': content => \"baseline\n\", strategy => 'bootstrap' }"
[ "$(cat "$WORK/bootstrap-missing.txt")" = 'baseline' ] \
  || fail "strategy => bootstrap did not create a missing file"

echo 'PASS: managed_file contract'
