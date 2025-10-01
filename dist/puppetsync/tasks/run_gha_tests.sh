#!/bin/bash

set -euo pipefail

if [ -n "${PT_path}" ] && [ -d "${PT_path}" ] ; then
    cd "${PT_path}"
else
    echo "'path' parameter not set or not a valid directory!" >&2
    exit 1
fi

act=$(type -p act || :)
if [ -z "$act" ] ; then
    echo "act not found.  Can't run GitHub Actions locally." >&2
    exit 1
fi

# Unfortunately, we need the jumbo image for `rpm`
act --rm -P ubuntu-latest=catthehacker/ubuntu:full-latest pull_request
