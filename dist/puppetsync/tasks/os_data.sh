#!/usr/bin/env bash

set -e

cd "${PT_path}"

for rocky_data in data/os/Rocky*.yaml ; do
    if [ ! -f "$rocky_data" ] ; then
        continue
    fi

    alma_data="${rocky_data/Rocky/AlmaLinux}"
    if [ ! -f "$alma_data" ] ; then
        cp "$rocky_data" "$alma_data"
    fi
done
