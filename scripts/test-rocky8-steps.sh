#!/bin/bash

set -euo pipefail

BUNDLE_EXE="${BUNDLE_EXE:-/opt/puppetlabs/bolt/bin/bundle}"
RUBY_EXE="${RUBY_EXE:-/opt/puppetlabs/bolt/bin/ruby}"

"$BUNDLE_EXE" --path=../../.vendor/bundle

"$BUNDLE_EXE" exec rake spec_prep && for i in spec/fixtures/modules/*; do SKIP_RAKE_TASKS=yes "$RUBY_EXE" ../../dist/puppetsync/tasks/modernize_metadata_json.rb "$i/metadata.json"; done

"$BUNDLE_EXE" exec rake spec_standalone
