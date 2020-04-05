#!/bin/bash
# ------------------------------------------------------------------------------
# Usage:
#
#  bolt task run puppetsync::install_gems path="$PWD/gems" gems='["pry", "octokit", "jira-ruby"]' -t localhost
#
# ------------------------------------------------------------------------------

[ -z "$PT_path" ] && { echo '=== $PT_path is empty'; env | grep -E '^(PT_|_)'; exit 1; }
[ -z "$PT_gems" ] && { echo '=== $PT_gems is empty'; env | grep -E '^(PT_|_)'; exit 1; }
[ -d "$(dirname "$PT_path")" ] || { echo "=== Directory $(dirname "$PT_path") not found"; env | grep -E '^(PT_|_)'; exit 2; }

gems=($(echo "$PT_gems" |  sed -e 's/[", \[\]]*/ /g'))
GEM_HOME="$PT_path" /opt/puppetlabs/bolt/bin/gem install --no-document jira-ruby octokit && echo "== PT_path='$PT_path' gems(${#gems[@]})='${gems[@]}'"



