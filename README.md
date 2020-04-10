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

A [bolt][bolt] plan to sync changes across multiple repositories, with workflow
support for Jira and PRs from forked GitHub repositories.

1. Clones repositories defined in a `Puppetfile.repos` (using `bolt puppetfile install`)
2. Checks out a new feature branch in each repository
3. Ensures a Jira subtask exists for each repository
4. Updates repository files using Puppet
5. Commits changes with a templated commit message
6. TODO: (in progress) Ensures a forked repository exists on GitHub
7. TODO: pushes changes up to each fork
8. TODO: ensures a Pull Request exists back to the original repository


Update files in multiple git repositories using Puppet, and submit changes
back to each repo as a Pull Request from a forked repository.

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

  /opt/puppetlabs/bin/bolt puppetfile install

2. Add `mod` entries for the repos you want to sync in `Puppetfile.repos`
3. Customize the [`puppetsync_planconfig.yaml`](#puppetsync_planconfigyaml) file to your workflow
4. Set [environment variables](#environment-variables) for JIRA and GitHub API authentication

## Usage

After [setup](#setup), sync all repos by running:

        /opt/puppetlabs/bin/bolt plan run puppetsync::sync --debug

To see what's going on under the hood (potentially less irritating when
`apply()` appears to hang for a long time when updating a lot of repos):

        /opt/puppetlabs/bin/bolt plan run puppetsync::sync --debug

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
| `GITHUB_USER`      | GitHub user      |     |
| `GITHUB_API_TOKEN` | GitHub API token |     |

(Recommended) To prevent bolt from collecting analytics, set this environment variable:

| Env variable                  | Purpose                                                                           |     |
| ------------                  | -------                                                                           | --- |
| `BOLT_DISABLE_ANALYTICS=true` | Prevent bolt's analytics from phoning home to tell Puppet about everything you do |     |

### `puppetsync_planconfig.yaml`

Example:

```yaml
---
jira:
  parent_issue: SIMP-7035
  project: SIMP
  jira_site: https://simp-project.atlassian.net
  subtask_title: 'Update .travis.yml pipeline in %COMPONENT%'

  # optional subtask fields:
  subtask_story_points: 1
  subtask_description: 'Push the new (static) Travis CI pipelines to %COMPONENT%'
  subtask_assignee: 'chris.tessmer'

git:
  commit_message: |
    (%JIRA_PARENT_ISSUE%) Update to new Travis CI pipeline

    This patch updates the Travis Pipeline to a static, standardized format
    that uses project variables for secrets. It includes an optional
    diagnostic mode to test the project's variables against their respective
    deployment APIs (GitHub and Puppet Forge).

    %JIRA_PARENT_ISSUE% #comment Update to latest pipeline in %COMPONENT%
    %JIRA_SUBTASK% #close

github:
  user: op-ct
```

## Limitations

* Requires git to be configured with SSH, with keys loaded into a running agent
* Probably only works from an \*nix host

[bolt]: https://puppet.com/docs/bolt/latest/bolt.html
