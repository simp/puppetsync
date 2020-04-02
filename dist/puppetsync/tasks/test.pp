#!/usr/bin/env bash
echo "your PT_message is '$PT_message'"
echo "your PT env is '$(env|egrep '^(PT_|_)' |sort)'"
echo "PWD is '$PWD'"

