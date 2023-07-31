#!/bin/bash

echo "=== $1"

grep_search='CentOS|OracleLinux|facts\.dig\(.os.?, ?.(name|distro)|facts\[.os.?\]\[.(name|distro)|operatingsystemmajrelease.*[87]|os.*release.*[87]|\<operatingsystem\>'

if [[ ! $(jq -r .name $1/metadata.json) =~ ^simp ]]; then
  echo "jq .name $1/metadata.jsonnot a simp module!"
  echo ">> SKIP $1: not a simp module!"
  exit
fi

egrep --color=always -r "$grep_search" \
  "$1"/manifests/ \
  "$1"/templates/ \
  "$1"/spec/{classes,defines,functions,hosts,unit} \
  "$1"/data/  2>/dev/null | egrep -v '^([^:#]+):\ *#|Nexenta'

# Check hiera path names
# You should probably include Rocky if you already need to specify CentOS by name
find "$1"/data \( -name 'CentOS*' -o -name 'OracleLinux*' -o -name 'Rocky*' \) 2>/dev/null
