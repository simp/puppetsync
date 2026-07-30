# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this repo is

puppetsync is a Puppet Bolt project that enforces a baseline of files (Gemfiles, CI workflows, lint configs, etc.) across the SIMP organization's GitHub repos. It clones each repo in a "repolist", applies a Puppet role to its working tree, commits the changes, and automates the change-management workflow: Jira subtasks, GitHub forks, pushes, and pull requests — with separate plans to approve and merge those PRs.

Files it pushes into other repos are stamped `THIS FILE IS MANAGED BY PUPPETSYNC`. Fixes to such files belong here (in the profile files/templates), never in the downstream repo.

## Commands

Bolt must be installed from an OS package (not the RubyGem); everything runs against `/opt/puppetlabs/bolt/bin`.

```sh
./Rakefile install        # Install gem deps (gem.deps.rb → .gems/) and Bolt modules (bolt-project.yaml)
bolt plan show            # Verify the puppetsync:: plans are loadable
rake -f Rakefile -T       # See all rake tasks (data file inspection, strings docs, clean/clobber)
rake -f Rakefile data:files   # Show which config/repolist the latest.yaml symlinks point at

# Main workflow (requires GITHUB_API_TOKEN; Jira stages also need JIRA_USER/JIRA_API_TOKEN)
bolt plan run puppetsync config=CONFIG_NAME repolist=REPOLIST_NAME
bolt plan run puppetsync::approve_github_prs
bolt plan run puppetsync::merge_github_prs

# Dry-run style inspection: list the pipeline stages a config will run
bolt plan run puppetsync options='{"list_pipeline_stages": true}' config=... repolist=...
```

- `config=` / `repolist=` name YAML files in `data/sync/configs/` and `data/sync/repolists/`; both default to the `latest.yaml` symlink in each directory.
- Use `--log-level info` to watch progress (the `apply()` step can look hung otherwise).
- Required environment variables and their purposes are documented in README.md ("Environment variables").
- Unit tests: `rspec` from the repo root (plain rspec; no bundle needed). The specs in `spec/` run the Bolt tasks as standalone scripts and sanity-check the Hiera data. CI (`.github/workflows/ci.yml`) also validates Puppet syntax and smoke-tests plan loading with `bolt plan show` / `list_pipeline_stages`. End-to-end validation is still running a plan against a test repolist (e.g. the `*_test.yaml` repolists).

## Architecture

Three layers, all data-driven via Hiera (`hiera.yaml` defines two separate hierarchies):

1. **Orchestration — `dist/puppetsync/`** (the `puppetsync` Bolt module)
   - `plans/init.pp` is the main plan; `approve_github_prs.pp`, `merge_github_prs.pp`, and `release_pupmod.pp` are the workflow companions.
   - Plans run a sequence of **pipeline stages** per repo, in parallel across repos. Each stage is a task in `dist/puppetsync/tasks/` (Ruby, executed locally via Bolt's `local` transport — see `inventory.yaml`). A repo that fails a stage is held back while others continue; failures are summarized at the end.
   - Which stages run is controlled entirely by the config file's `puppetsync.plans.<plan>.stages` list — adding a new capability usually means writing a task here and listing it in a config.
   - `functions/` holds plan-support Puppet functions (target setup, fact seeding, result summarization).

2. **The baseline — `modules/role/` and `modules/profile/`**
   - One stage (`apply_puppet_role`) applies a `role::*` class to each cloned repo's working tree. The role is chosen per repo via Hiera's `classes` key, keyed off the `project_type` fact (see `data/project_types/*.yaml`).
   - `role::*` classes are thin lists of `profile::*` includes. Each profile manages a specific slice of the baseline (Gemfile, git files, GitHub Actions workflows, lint configs, ...), writing into `$::repo_path`.
   - Static file sources live in `modules/profile/files/`, templates in `modules/profile/templates/`. Dotfiles are stored with a leading underscore (`_gitignore` → `.gitignore`). Profiles use fallback lookup chains so a repo-specific override (`_gitignore.<repo_name>`, or `_github/workflows/<action>.<repo_name>.yml`) beats the generic file.

3. **Data — `data/`**
   - `data/sync/configs/*.yaml` — per-session config (`puppetsync::plan_config`): pipeline stages, Jira parent issue, commit message template, PR settings. See `examples/` and README.md for the full schema.
   - `data/sync/repolists/*.yaml` — per-session target list (`puppetsync::repos_config`): repo URLs and branches. `pupmods.yaml` is the canonical all-modules list.
   - `data/repos/*.yaml`, `data/project_types/*.yaml` — per-repo and per-project-type Hiera data for the apply step (classification, profile parameters like which GHA workflows must be present/absent).
   - The two Hiera hierarchies are distinct: `plan_hierarchy` resolves plan-level lookups from config/repolist/batch names; the regular hierarchy resolves per-target data during `apply()` from facts (`project_type`, `module_metadata`).

## Starting a new sync session

1. Create or reuse a repolist in `data/sync/repolists/` and a config in `data/sync/configs/` (copy a recent dated one; the naming convention is `YYYYMMDD-description.yaml`).
2. Point the `latest.yaml` symlinks at them (optional, but lets you omit `config=`/`repolist=`).
3. If the change needs new behavior, add/modify a task (one-off transformations) or a profile (persistent baseline files), and list any new stage in the config.
4. Do **not** update `CHANGELOG.md` — it is frozen (no versioned releases to collect entries, and per-PR edits conflicted with every in-flight PR). Descriptive squash-merge PR titles are the changelog.

## Current context

- Repos cloned during a run land in `_repos/` (gitignored; `rake clobber` removes it).
- Renovate now handles dependency updates in downstream repos; puppetsync's remaining job is workflow templates and config files. GitLab CI support has been removed — GitHub Actions is the only CI target.
