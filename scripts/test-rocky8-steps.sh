#!/bin/bash

set -euo pipefail


[ -d "${PT_path:-xxxxxx}" ] && cd "${PT_path}"

BUNDLE_EXE="${BUNDLE_EXE:-/opt/puppetlabs/bolt/bin/bundle}"
RUBY_EXE="${RUBY_EXE:-/opt/puppetlabs/bolt/bin/ruby}"

"$BUNDLE_EXE" --path=../../.vendor/bundle
rm -rf spec/fixtures/modules/pupmod-* || :
"$BUNDLE_EXE" exec rake spec_prep && for i in spec/fixtures/modules/*; do SKIP_RAKE_TASKS=yes "$RUBY_EXE" ../../dist/puppetsync/tasks/modernize_metadata_json.rb "$i/metadata.json"; done

SPEC_OPTS="${SPEC_OPTS:---no-fail-fast}" "$BUNDLE_EXE" exec rake spec_standalone |& tee ../"$( jq .name metadata.json ).rspec.log" && rm -f Gemfile.lock
