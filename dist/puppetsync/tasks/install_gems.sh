#!/bin/bash

[ -z "$PT_gem_install_path" ] && { echo '=== $PT_gem_install_path is empty'; env | grep -E '^(PT_|_)'; exit 1; }
[ -d "$(dirname "$PT_gem_install_path")" ] || { echo "=== Directory $(dirname "$PT_gem_install_path") not found"; env | grep -E '^(PT_|_)'; exit 2; }

GEM_HOME="$PT_gem_install_path" /opt/puppetlabs/bolt/bin/gem install --no-document jira-ruby  && echo "== PT_gem_install_path='$PT_gem_install_path'"



