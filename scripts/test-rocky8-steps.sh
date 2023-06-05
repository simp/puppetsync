#!/bin/bash

set -euo pipefail

BUNDLE=/opt/puppetlabs/bolt/bin/bundle
RUBY=/opt/puppetlabs/bolt/bin/ruby

"$BUNDLE" --path=../../.vendor/bundle

"$BUNDLE" exec rake spec_prep && for i in spec/fixtures/modules/*; do SKIP_RAKE_TASKS=yes "$RUBY" ../../dist/puppetsync/tasks/modernize_metadata_json.rb "$i/metadata.json"; done

"$BUNDLE" exec rake spec_standalone
