#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

[ -d "${PT_path:-xxxxxx}" ] && cd "${PT_path}"

BUNDLE_EXE="${BUNDLE_EXE:-/opt/puppetlabs/bolt/bin/bundle}"
RUBY_EXE="${RUBY_EXE:-/opt/puppetlabs/bolt/bin/ruby}"

"$BUNDLE_EXE" --path=../../.vendor/bundle
rm -rf spec/fixtures/modules/pupmod-* || :
"$BUNDLE_EXE" exec rake spec_prep && for i in spec/fixtures/modules/*; do 
  test -f "$i/metadata.json" && SKIP_RAKE_TASKS=yes "$RUBY_EXE" ../../dist/puppetsync/tasks/modernize_metadata_json.rb "$i/metadata.json" || :
done

[[ "${SKIP_TESTS:-no}" == yes ]] && exit 0 || :
SPEC_OPTS="${SPEC_OPTS:---no-fail-fast}" "$BUNDLE_EXE" exec rake spec_standalone 2>&1 | tee ../"$( jq -r .name metadata.json ).rspec.log" && rm -f Gemfile.lock
