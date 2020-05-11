# puppetsync

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Setup](#setup)
  * [Requirements](#requirements)
  * [Getting started](#getting-started)
* [Usage](#usage)
* [Reference](#reference)
  * [Environment variables](#environment-variables)
  * [`puppetsync_planconfig.yaml`](#puppetsync_planconfigyaml)
* [Limitations](#limitations)

<!-- vim-markdown-toc -->

## Description

**puppetsync** manages your infrastructure code like infrastructure-as-code!

It is a collection of embedded [Puppet bolt][bolt] plans to help orchestrate
updates to a "baseline" of common assets across multiple git repositories,
using Puppet and Bolt.

The main plan (`puppetsync`) executes the workflow as series of pipeline
of stages for each repo.  It:

1. Clones `:git` repositories defined in a `Puppetfile.repos` file

Then, for each repository, it will:

2. Ensure a Jira subtask exists to track the change
3. Check out a new git feature branch
4. Apply Puppet manifests to enforce a common repository asset baseline
5. Commit changes to git with a templated commit message
6. Ensure the user has forked repository on GitHub
7. Push changes up to the user's forked repository
8. Submit a Pull Request to merge the changes back the original repository and branch

If an individual repo encounters failures during a stage, it will be held back
while the other repos proceed in their workflows.

All failures are summarized after the plan finished executing.


## Setup

### Requirements

* [Puppet Bolt 2.x][bolt]
* Puppet modules (in bolt project's `Puppetfile`):
  * [puppetlabs-stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git)
  * [puppetlabs/ruby_task_helper](https://github.com/puppetlabs/puppetlabs-ruby_task_helper.git)
* API authentication tokens for Jira and GitHub
* The `git` command must be available
  * SSH + ssh-agent must be set up to push changes

### Getting started

1. Use `bolt` to download the project's dependencies from `Puppetfile`:

        ./Rakefile install

   Or:

         /opt/puppetlabs/bolt/bin/gem install --user-install -g gem.deps.rb
         /opt/puppetlabs/bin/bolt puppetfile install

2. Add `mod` entries for the repos you want to sync in `Puppetfile.repos`
3. Customize the [`puppetsync_planconfig.yaml`](#puppetsync_planconfigyaml) file to your workflow
4. Set [environment variables](#environment-variables) for JIRA and GitHub API authentication

## Usage

After [setup](#setup), sync all repos by running:

        /opt/puppetlabs/bin/bolt plan run puppetsync

To see what's going on under the hood (potentially less irritating when
`apply()` appears to hang for a long time when updating a lot of repos):

        /opt/puppetlabs/bin/bolt plan run puppetsync --debug


To list all pipeline stages in a plan, run:

        /opt/puppetlabs/bolt/bin/bolt plan run puppetsync options='{"list_pipeline_stages": true}'

## Reference

### Environment variables

To create Jira subtasks, these environment variables are necessary:

| Env variable | Purpose   |                           |
| ------------ | -------   | ------------------------- |
| `JIRA_USER`  | Jira user | Probably an email address |
| `JIRA_API_TOKEN` | Jira API token | You MUST generate an API token (basic auth no longer works). To do so, you must have Jira instance access rights.  You can generate a token here: https://id.atlassian.com/manage/api-tokens |

To fork GitHub repositories and submit Pull Requests, these environment variables are necessary:

| Env variable       | Purpose          |     |
| ------------       | -------          | --- |
| `GITHUB_API_TOKEN` | GitHub API token |     |

(Recommended) To prevent bolt from collecting analytics, set this environment variable:

| Env variable                  | Purpose                                                                           |     |
| ------------                  | -------                                                                           | --- |
| `BOLT_DISABLE_ANALYTICS=true` | Prevent bolt's analytics from phoning home to tell Puppet about everything you do |     |

### `puppetsync_planconfig.yaml`

Example:

```yaml
---
puppetsync:
  puppet_role: 'role::pupmod_travis_only'
  permitted_project_types:
    - pupmod

jira:
  parent_issue: SIMP-7035
  project: SIMP
  jira_site: https://simp-project.atlassian.net
  subtask_title: 'Update .travis.yml pipeline in %COMPONENT%'

  # optional subtask fields:
  subtask_story_points: 1
  subtask_assignee: 'chris.tessmer'

git:
  commit_message: |
    (%JIRA_PARENT_ISSUE%) Update to new Travis CI pipeline

    This patch updates the Travis Pipeline to a static, standardized format
    that uses project variables for secrets. It includes an optional
    diagnostic mode to test the project's variables against their respective
    deployment APIs (GitHub and Puppet Forge).

    [%JIRA_PARENT_ISSUE%] #comment Update to latest pipeline in %COMPONENT%
    [%JIRA_SUBTASK%] #close

github:
  pr_user: op-ct
  approval_message: ':+1: lgtm'
```

## Limitations

* Requires git to be configured with SSH, with keys loaded into a running agent
* Probably only works from an \*nix host

[bolt]: https://puppet.com/docs/bolt/latest/bolt.html
