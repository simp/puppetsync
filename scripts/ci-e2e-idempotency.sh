#!/bin/bash
# End-to-end test for puppetsync idempotency (#49).
#
# Runs the sync plan twice against a local file:// fixture repo:
#   - run 1 commits a change (drop_glci_config removes the fixture's
#     .gitlab-ci.yml) and must report "1 ok"
#   - run 2 has nothing to do and must report "1 unchanged", skipping the
#     GitHub fork/remote/push/PR stages. Those stages are enabled for run 2
#     with dummy tokens and no git remotes configured, so if the
#     skip-unchanged filter ever breaks, they fail loudly.
#
# Requires bolt (openbolt) and the project's modules (./Rakefile install).
set -euo pipefail
cd "$(dirname "$0")/.."

BOLT="${BOLT:-/opt/puppetlabs/bolt/bin/bolt}"
export BOLT_DISABLE_ANALYTICS=true
export GITHUB_API_TOKEN="${GITHUB_API_TOKEN:-dummy}"
export GITLAB_API_TOKEN="${GITLAB_API_TOKEN:-dummy}" # required until #51 merges
export GIT_AUTHOR_NAME='puppetsync e2e' GIT_AUTHOR_EMAIL='e2e@example.com'
export GIT_COMMITTER_NAME='puppetsync e2e' GIT_COMMITTER_EMAIL='e2e@example.com'

WORK="$(mktemp -d)"
CONFIG=data/sync/configs/zz-ci-e2e.yaml
REPOLIST=data/sync/repolists/zz-ci-e2e.yaml
trap 'rm -rf "$WORK" "$CONFIG" "$REPOLIST" _repos/fixture-repo.git' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- fixture upstream: one repo with a .gitlab-ci.yml to drop ---------------
git init -q -b main "$WORK/seed"
git -C "$WORK/seed" config user.email e2e@example.com
git -C "$WORK/seed" config user.name 'puppetsync e2e'
echo hello > "$WORK/seed/README.md"
printf 'stages:\n  - old\n' > "$WORK/seed/.gitlab-ci.yml"
git -C "$WORK/seed" add -A
git -C "$WORK/seed" commit -qm seed
git clone -q --bare "$WORK/seed" "$WORK/fixture-repo.git"

# --- session config/repolist -------------------------------------------------
cat > "$CONFIG" <<'YAML'
---
puppetsync::plan_config:
  puppetsync:
    permitted_project_types: []
    plans:
      sync:
        filter_permitted_repos: false
        stages:
          - checkout_git_feature_branch_in_each_repo
          - drop_glci_config
          - git_commit_changes
  git:
    feature_branch: TEST-9999
    commit_message: |
      (TEST-9999) ci e2e idempotency test for %COMPONENT%
YAML

cat > "$REPOLIST" <<YAML
---
puppetsync::repos_config:
  file://$WORK/fixture-repo.git:
    branch: main
YAML

# --- run 1: expect a commit --------------------------------------------------
echo '== run 1 (expect: 1 ok)'
OUT1="$("$BOLT" plan run puppetsync config=zz-ci-e2e repolist=zz-ci-e2e 2>&1)" \
  || { echo "$OUT1"; fail 'run 1 exited nonzero'; }
grep -q '1 ok / 0 unchanged / 0 failed' <<<"$OUT1" \
  || { echo "$OUT1"; fail 'run 1 did not report "1 ok / 0 unchanged / 0 failed"'; }

# --- run 2: expect unchanged + GitHub stages skipped -------------------------
echo '== run 2 (expect: 1 unchanged, GitHub stages skipped)'
RUN2_STAGES='["checkout_git_feature_branch_in_each_repo","drop_glci_config","git_commit_changes","ensure_github_fork","ensure_git_remote","git_push_to_remote","ensure_github_pr"]'
OUT2="$("$BOLT" plan run puppetsync config=zz-ci-e2e repolist=zz-ci-e2e \
  options="{\"clone_git_repos\": false, \"stages\": $RUN2_STAGES}" 2>&1)" \
  || { echo "$OUT2"; fail 'run 2 exited nonzero'; }
grep -q '0 ok / 1 unchanged / 0 failed' <<<"$OUT2" \
  || { echo "$OUT2"; fail 'run 2 did not report "0 ok / 1 unchanged / 0 failed"'; }
for stage in ensure_github_fork ensure_git_remote git_push_to_remote ensure_github_pr; do
  grep -q "SKIPPING 1 UNCHANGED TARGET(S) FOR STAGE: $stage" <<<"$OUT2" \
    || { echo "$OUT2"; fail "run 2 did not skip stage $stage"; }
done

echo 'PASS: e2e idempotency test'
