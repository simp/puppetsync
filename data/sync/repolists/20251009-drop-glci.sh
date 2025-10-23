#!/bin/bash

set -e

org=simp

repos=( $( gh repo list "$org" --no-archived --limit 500 --source --json name | jq -r .[].name ) )

out=""
for repo in "${repos[@]}"; do
    branch=$( gh repo view "$org/$repo" --json defaultBranchRef | jq -r '.defaultBranchRef.name' )
    files=$( gh api "/repos/$org/$repo/git/trees/$branch" -q '.tree[]|.path' )
    if ! grep -q '^\.gitlab-ci\.yml$' <<< "$files"; then
	continue
    fi
    out+="  $( gh repo view "$org/$repo" --json url -q '.url' ):"$'\n'
    out+="    branch: $branch"$'\n'
done

if [ -n "$out" ]; then
    cat <<END
---
puppetsync::repos_config:
${out%$'\n'}
END
fi
