# puppetsync

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Requirements](#requirements)
* [Setup](#setup)
* [Usage](#usage)
* [Reference](#reference)
  * [`puppetsync_planconfig.yaml`](#puppetsync_planconfigyaml)

<!-- vim-markdown-toc -->

## Description

Sync files across multiple git repositories using Puppet, and submit the changes as GitHub PRs.
fork-friendly workflow.
## Requirements

* [Puppet Bolt 2.x](https://puppet.com/docs/bolt/latest/bolt.html)

* To create Jira subtasks

  these environment variables are necessary:
  | Env variable | Purpose |     |
  | ------------ | ------- | --- |
  | `JIRA_API_TOKEN` | Jira API token |
  | `JIRA_USER`      | Jira user      |

## Setup

1. Customize the [`puppetsync_planconfig.yaml`](#puppetsync_planconfigyaml) file to your workflow
2. Add the repos you want to update as `mod` entries in `Puppetfile.repos`
3. Download the modules:

   ```sh
   /opt/puppetlabs/bin/bolt puppetfile install
   ```

## Usage

```sh
/opt/puppetlabs/bin/bolt plan run puppetsync::sync --debug
```

## Reference

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
