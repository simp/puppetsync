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
echo "== PT_path='$PT_path' PT_gems='${PT_gems}' gems(${#gems[@]})='${gems[@]}'"
IFS=$'\n' read -rd '' -a gems < <(echo $PT_gems | /opt/puppetlabs/bolt/bin/ruby -r json -ne 'puts JSON.parse $_')
GEM_HOME="$PT_path" /opt/puppetlabs/bolt/bin/gem install --no-document "${gems[@]}" && echo "== PT_path='$PT_path' gems(${#gems[@]})='${gems[@]}'"



