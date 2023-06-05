#!/bin/bash


echo "=== $1"

grep_search='CentOS|OracleLinux|facts\.dig\(.os.?, ?.(name|distro)|facts\[.os.?\]\[.(name|distro)|operatingsystemmajrelease.*[87]|os.*release.*[87]|\<operatingsystem\>'

egrep --color=always -r "$grep_search" \
  "$1"/manifests/ \
  "$1"/templates/ \
  "$1"/spec/{classes,defines,functions,hosts,unit} \
  "$1"/data/  2>/dev/null | egrep -v '^([^:#]+):\ *#|Nexenta'



# chech hiera names
# Should have Rocky if you have CentOS
find "$1"/data \( -name 'CentOS*' -o -name 'OracleLinux*' -o -name 'Rocky*' \) 2>/dev/null
