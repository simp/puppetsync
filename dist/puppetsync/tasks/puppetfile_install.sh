#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# Usage:
#
#  bolt task run puppetsync::install_gems path="$PWD/gems" gems='["pry", "octokit", "jira-ruby"]' -t localhost
#
# ------------------------------------------------------------------------------

# shellcheck disable=SC2016
[ -z "${PT_project_dir:-}" ] && { echo '=== $PT_project_dir is empty'; env | grep -E '^(PT_|_)'; exit 1; }
PT_puppetfile="${PT_puppetfile:-Puppetfile.repos}"
[ -d "$PT_project_dir" ] || { echo "=== Directory '$PT_project_dir' not found"; env | grep -E '^(PT_|_)'; exit 2; }

puppetfile="$(realpath --relative-to="${PT_project_dir}" "$PT_puppetfile")"

cd "$PT_project_dir"
>&2 /opt/puppetlabs/bolt/bin/r10k puppetfile install --puppetfile="$puppetfile" --moduledir="${PT_moduledir:-_repos}" --verbose=debug

