# Update assets across multiple git repos using Bolt tasks and Puppet
#
# Supports workflow tasks, like:
#   - Ensuring a Jira subtask exists to track each repo
#     (requires `$JIRA_USER` and `$JIRA_API_TOKEN`)
#   - Ensuring the user's GitHub account a has fork of each upstream repo
#     (requires `$GITHUB_API_TOKEN`)
#   - Pushing up changes and submitting Pull Requests back to the original GitHub repo
#     (requires `$GITHUB_API_TOKEN`)
#
# Files:
#   - `data/sync/repolists/*.yaml`: Defines git repos (with branch) to clone and update
#   - `data/sync/config/*.yaml`:    Defines settings for a particular update session
#
# @summary Update assets across multiple git repos using Bolt tasks and Puppet
#
# @example
#
#   1. Set environment vars: `JIRA_USER`, `JIRA_API_TOKEN`, `GITHUB_API_TOKEN`
#   2. Select/create/edit relevant config and repolist files under `data/sync/`
#   3. Run:
#
#      bolt plan run puppetsync::sync config=<config> repolist=<repolist>
#
# @param targets
#   Bolt requires this parameter to exist, however: **it is unused.**
#   All targets are generated as `transport: local` during execution
#
# @param puppet_role
#   An optional Puppet class to classify and apply to all repos.
#
#   * If left undefined, the Puppet classes for each target will be
#     looked up from Hiera (using the key `classes`)
#   * When set, it is usually defined in the config file's
#    `puppetsync::puppet_role` key in Hiera.
#
# @param project_dir
#   The bolt project directory.  Defaults to `$PWD`.
#
# @param repolist
#   Specifies the list of repos to clone, modify, and PR.
#   The name maps to a Hiera .yaml file under `data/sync/repolists/`
#   (Default: 'default')
#
# @param config
#   Specifies the puppetsync settings used to customize the sync session.
#   The name maps to a Hiera .yaml file under `data/sync/configs/`
#   (Default: 'default')
#
# @param puppetsync_config
#   A Hash of puppetsync settings used to customize the sync session.
#   By default, this is loaded from Hiera data based on the `repolist`
#   parameter.
#
# @param repos_config
#   A Hash of repos and branches to to clone, modify, and PR.
#   By default, this is loaded from Hiera data based on the `config` parameter.
#
# @param extra_gem_path
#   Absolute path to a gem path with extra gems the bolt interpreter will to run
#   some of the Ruby tasks.  This may be needed to provide rubygems for Jira,
#   GitHub, and `puppetsync::output_pipeline_results`
#
#   You can quickly install gems into the default extra_gem_path by running:
#
#          ./Rakefile install
#
#   (Default: `${project_dir}/.plan.gems`)
#
# @param jira_username
#    Jira API username (probably an email address)
#    (Default: Environment variable `$JIRA_USER`)
#
# @param jira_token
#   Jira API token
#    (Default: Environment variable `$JIRA_API_TOKEN`)
#
#   _NOTES_
#   - You MUST generate a Jira API token (basic auth no longer works).
#   - To do so, you must have Jira instance access rights.
#   - You can generate a token here: https://id.atlassian.com/manage/api-tokens
#
# @param github_token
#   GitHub API token
#    (Default: Environment variable `$GITHUB_API_TOKEN`)
#
# @param options
#   Hash of options used to customize tweak local settings in the plan
#   This is generally provided under the `puppetsync::plan_config` > `plans` >
#   `sync` key of the `puppetsync_config` pHash
#
# @author Chris Tessmer <chris.tessmer@onyxpoint.com>
#
# ------------------------------------------------------------------------------
plan puppetsync(
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  String[1]            $batchlist              = '---',
  String[1]            $config                 = 'latest',
  String[1]            $repolist               = 'latest',
  Hash                 $puppetsync_config      = lookup('puppetsync::plan_config'),
  Hash                 $repos_config           = lookup('puppetsync::repos_config'),
  Optional[String[1]]  $puppet_role            = $puppetsync_config.dig('puppetsync','puppet_role'),
  Stdlib::Absolutepath $extra_gem_path         = "${project_dir}/.plan.gems",
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  Sensitive[String[1]] $gitlab_token           = Sensitive(system::env('GITLAB_API_TOKEN')),
  Hash                 $options                = {},
) {

  $opts = {
    'clone_git_repos'          => true,
    'github_api_delay_seconds' => 5,
   } + getvar('puppetsync_config.puppetsync.plans.sync').lest || {{}} + $options
  $repos = puppetsync::setup_project_repos( $puppetsync_config, $repos_config, $project_dir, $opts )
  $feature_branch    = getvar('puppetsync_config.git.feature_branch')

  # ----------------------------------------------------------------------------
  # - [x] Install repos from Puppetfile.repos
  # - [x] git checkout -b BRANCHNAME
  # - [x] ensure jira subtask exists for repo
  # - [x] set up facts
  # --------
  # - [x] puppet apply
  # - [x] run transformations?  tasks?
  # -------
  # - [x] commit changes
  # - [x] ensure GitHub fork of upstream repo exists
  # - [x] ensure a remote exists in the local git repo for the forked GitHub repo
  # - [x] push changes to user's GitHub fork
  # - [x] PR changes to upstream repository on GitHub
  # -------
  # - [x] error catching to filter out repos with problems
  #   - [x] report at the end
  # - [x] move task scripts into files/ and convert tasks into shims
  #   - [x] goal: make logic in each task easy to smoke test on its own
  # -------
  # stretch goals:
  # - [x] only run on repos that match a list of accepted project_types
  # - [x] feature flag each step (on, off, noop?)
  # - [ ] support --noop in each pipeline_stage
  # - [ ] push changes using HTTPS basic auth + GitHub token (CI friendly)
  # - [ ] move templating logic from jira task's ruby code into plan logic
  # - [ ] spec tests
  # - [ ] enhanced idempotency
  #   - [ ] detect closed JIRA subtask for same subtask and (by default) refuse to open a new one
  #   - [ ] detect merged PR for same feature and (by default) refuse to open a new one
  # - [x] validate (e.g., gitlab_ci lint, flag obvious disasters) before committing changes
  # ----------------------------------------------------------------------------

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'install_gems',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task( 'puppetsync::install_gems',
      'localhost',
      'Install RubyGems gems on localhost that are required to run tasks',
      {
        'path'          => $extra_gem_path,
        'gems'          => ['jira-ruby:~> 2.0', 'octokit:~> 4.18'],
        '_catch_errors' => false,
      }
    )
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'checkout_git_feature_branch_in_each_repo',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task( 'puppetsync::checkout_git_feature_branch_in_each_repo',
      'localhost',
      "Check out git branch '${feature_branch} in all repos'",
      'branch'        => $feature_branch,
      'repo_paths'    => $repos.map |$repo| { $repo.vars['repo_path'] },
      '_catch_errors' => false,
    )
  }


  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'apply_puppet_role',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    apply( $ok_repos,
      '_description' => "Apply Puppet role ${puppet_role}",
      '_noop' => false,
      _catch_errors => true,
    ){
      if $puppet_role {
        include $puppet_role
      } else {
        warning('No $puppet_role given; looking up classes from Hiera instead')
        $classes = lookup('classes', undef, undef, [])
        warning("Hiera classes: [${classes.join(',')}]")
        $classes.include
      }
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'remove_el6',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::remove_el6',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      $file_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton/metadata.json.erb",
        default           => "${repo.vars['repo_path']}/metadata.json",
      }

      Hash.new({
        'file' => $file_path,
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'remove_puppet6',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::remove_puppet6',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      $dir_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton/",
        default           => "${repo.vars['repo_path']}",
      }

      Hash.new({
        'file' => "${dir_path}/.gitlab-ci.yml",
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'comment_puppet8_spec_tests',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::comment_puppet8_spec_tests',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      $dir_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton/",
        default           => "${repo.vars['repo_path']}",
      }

      Hash.new({
        'file' => "${dir_path}/.gitlab-ci.yml",
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'modernize_gitlab_files',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::modernize_gitlab_files',
      $ok_repos,
      '_catch_errors'  => false,
    ) |$repo| {
      $dir_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton",
        default           => "${repo.vars['repo_path']}",
      }

      Hash.new({
        'file' => "${dir_path}/.gitlab-ci.yml",
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'lint_gitlab_ci',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task( 'puppetsync::lint_gitlab_ci',
      'localhost',
      "lint .gitlab-ci.yml file to make sure it hasn't become an abomination",
      {
        'repo_paths'               => $ok_repos.map |$x| { $x.vars['repo_path'] },
        'gitlab_private_api_token' => $gitlab_token.unwrap,
        '_catch_errors'            => false,
      }
    )
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'modernize_fixtures',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::modernize_fixtures',
      $ok_repos,
      '_catch_errors'  => false,
    ) |$repo| {
      $file_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton/.fixtures.yml.erb",
        default           => "${repo.vars['repo_path']}/.fixtures.yml",
      }
      Hash.new({
        'filename' => $file_path,
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'os_data',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::os_data',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      Hash.new({
        'path' => "${repo.vars['repo_path']}"
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'modernize_metadata_json',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::modernize_metadata_json',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      $file_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton/metadata.json.erb",
        default           => "${repo.vars['repo_path']}/metadata.json",
      }
      Hash.new({
        'filename' => $file_path,
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'modernize_spec_helper',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::modernize_spec_helper',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      $file_path = $repo.facts['project_type'] ? {
        'pupmod_skeleton' => "${repo.vars['repo_path']}/skeleton/spec/spec_helper.rb",
        default           => "${repo.vars['repo_path']}/spec/spec_helper.rb",
      }
      Hash.new({
        'filename' => $file_path,
      })
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'run_spec_tests',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    run_task_with('puppetsync::run_spec_tests',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      Hash.new({
        'path' => "${repo.vars['repo_path']}"
      })
    }
  }


  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'generate_reference_md',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $commit_message = $puppetsync_config.dig('git','commit_message').lest || {''}
    run_task_with(
      'puppetsync::generate_reference_md',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      {
        'filename'    => "${repo.vars['repo_path']}/metadata.json",
        'auto_commit' => true,
      }
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'git_commit_changes',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $commit_message = $puppetsync_config.dig('git','commit_message').lest || {''}
    run_task_with(
      'puppetsync::git_commit',
      $ok_repos,
      '_catch_errors'  => true,
    ) |$repo| {
      {
        'repo_path'      => $repo.vars['repo_path'],
        'commit_message' => puppetsync::template_git_commit_message($repo,$puppetsync_config),
      }
    }
  }


  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_github_fork',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $results = run_task_with(
      'puppetsync::ensure_github_fork', $ok_repos, '_catch_errors' => true
    ) |$repo| {{
      'extra_gem_path'   => $extra_gem_path,
      'github_repo'      => $repo.vars['repo_url_path'],
      'github_authtoken' => $github_token.unwrap,
    }}

    $ok_repos.each |$repo| {
      if $results.ok {
        $result = $results.filter |$r| { $r.target.name == $repo.name }[0]
        $repo.set_var('user_repo_fork', $result.value)
        out::message(
          "-- GitHub user's repo fork: '${repo.vars['user_repo_fork']['user_fork']}'"
        )
      }
    }
    $results
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_git_remote',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.each |$repo| {$repo.set_var('remote_name', 'user_forked_repo')}
    $results = run_task_with(
      'puppetsync::ensure_git_remote', $ok_repos, '_catch_errors' => true
    ) |$repo| {
      {
        'repo_path'     => $repo.vars.get('repo_path'),
        'remote_url'    => $repo.vars.get('user_repo_fork.ssh_url'),
        'remote_name'   => $repo.vars.get('remote_name'),
      }
    }

    $results.each |$r| {
      if !$r.ok {
        out::message( @("END")
          Running puppetsync::ensure_git_remote failed on ${r.target.name}:
          ${r.error.msg}

          ${r.error.details}
          END
        )
      }
    }
  }
  # TODO if any repos were forked, wait 5 minutes for GitHub to catch up

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'git_push_to_remote',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$repo| {
      $results = run_command(
        "cd '${repo.vars['repo_path']}'; git push '${repo.vars['remote_name']}' '${feature_branch}' -f",
        $repo,
        "Push branch '${feature_branch}' to forked repository",
        { '_catch_errors' => true }
      )
      $results.first
    }
  }


  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_gitlab_remote',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $results = run_task_with(
      'puppetsync::ensure_git_remote', $ok_repos, '_catch_errors' => true,
    ) |$repo| {
      {
        'repo_path'     => $repo.vars['repo_path'],
        'remote_url'    => $repo.vars['user_repo_fork']['ssh_url'].regsubst($puppetsync_config['github']['pr_user'],'simp').regsubst('github','gitlab'),
        'remote_name'   => 'gitlab_repo',
      }
    }
  }
  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'git_push_to_gitlab',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$repo| {
      $results = run_command(
        "cd '${repo.vars['repo_path']}'; git push 'gitlab_repo' '${feature_branch}:${feature_branch}' -f",
        $repo,
        "Push branch '${feature_branch}' to gitlab repository",
        { '_catch_errors' => true }
      )
      $results.first
    }
  }


  # TODO if any repos were forked, wait 5 minutes for GitHub to catch up

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_github_pr',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$repo| {
      $results = run_task( 'puppetsync::ensure_github_pr', $repo,
        'Ensure there is a GitHub PR for this commit',
        {
          'target_repo'      => $repo.vars['repo_url_path'],
          'target_branch'    => $repo.vars['mod_data']['branch'],
          'fork_branch'      => $feature_branch,
          'commit_message'   => puppetsync::template_git_commit_message($repo,$puppetsync_config),
          'github_authtoken' => $github_token.unwrap,
          'extra_gem_path'   => $extra_gem_path,
          '_catch_errors'    => true,
        }
      )

      if $results.ok {
        $created_status = $results.first.value['pr_created'] ? {
          true    => ' (just created)',
          default => '',
        }
        out::message( "-- GitHub user's PR: '${results.first.value['pr_url']}'${created_status}")
      } else {
        out::message(
          [ "Running puppetsync::ensure_github_pr failed on ${repo.name}:",
            $results.first.error.msg,'','', $results.first.error.details,'', ].join("\n")
        )
      }
      ctrl::sleep($opts['github_api_delay_seconds'])
      $results.first
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'release_pupmod',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $commit_message = $puppetsync_config.dig('git','commit_message').lest || {''}
    run_task_with(
      'puppetsync::release_pupmod',
      $ok_repos,
      '_catch_errors'  => false,
    ) |$repo| {
      {
        'filename'                => "${repo.vars['repo_path']}/metadata.json",
        'upstream_remote'         => 'origin',
        'overwrite_existing_tags' => 'false',
        'dry_run'                 => 'true' # FIXME change to true before release
      }
    }
  }

  puppetsync::output_pipeline_results( $repos, $project_dir, $opts)
}
