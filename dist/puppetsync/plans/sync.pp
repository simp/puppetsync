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
#   - `Puppetfile.repos`:           Defines :git repos (with :branch) to clone and update
#   - `puppetsync_planconfig.yaml`: Defines settings for this particular update session
#
# @summary Update assets across multiple git repos using Bolt tasks and Puppet
#
# @example
#
#   1. Set environment vars: `JIRA_USER`, `JIRA_API_TOKEN`, `GITHUB_API_TOKEN`
#   2. Run:
#
#      bolt plan run puppetsync::sync
#
# @param targets
#   The parameter is required to exist, but is unused.
#   All targets are generated as `transport: local` during execution
#
# @param puppet_role
#   A Puppet class to classify and apply to all repos
#
# @param project_dir
#   The bolt project directory.  Defaults to `$PWD`.
#
#   @todo make this a function? (It's a hacky way to get the project dir)
#
# @param puppetfile
#   A special Puppetfile with :git repos to clone, update, and PR
#   (Default: `${project_dir}/Puppetfile.repos`)
#
# @param puppetsync_config_path
#   Path to a YAML file with settings for a specific update session
#   See the project README.md for an example.
#   (Default: `${project_dir}/puppetsync_planconfig.yaml`)
#
# @param puppetsync_config
#   Hash of settings for this specific update session
#
# @param extra_gem_path
#   Path to a gem path with extra gems the bolt interpreter will to run
#   some of the Ruby tasks.
#   (Default: `${project_dir}/.gems`)
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
#   - You MUST generate an API token (basic auth no longer works).
#   - To do so, you must have Jira instance access rights.
#   - You can generate a token here: https://id.atlassian.com/manage/api-tokens
#
# @param github_token
#   GitHub API token
#    (Default: Environment variable `$GITHUB_API_TOKEN`)
#
# @author Chris Tessmer <chris.essmer@onyxpoint.com>
#
# ------------------------------------------------------------------------------
plan puppetsync::sync(
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  Stdlib::Absolutepath $puppetfile             = "${project_dir}/Puppetfile.repos",
  Stdlib::Absolutepath $puppetsync_config_path = "${project_dir}/puppetsync_planconfig.yaml",
  Hash                 $puppetsync_config      = loadyaml($puppetsync_config_path),
  String[1]            $puppet_role            = $puppetsync_config.dig('puppetsync','puppet_role').lest || { 'role::unset' },
  Stdlib::Absolutepath $extra_gem_path         = "${project_dir}/.gems",
  String[1]            $jira_username          = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token             = Sensitive(system::env('JIRA_API_TOKEN')),
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  Hash                 $options                = {},
) {
  $opts = {
    'clone_git_repos' => true,
   } + getvar('puppetsync_config.puppetsync.plans.sync').lest || {{}} + $options
  $repos = puppetsync::setup_project_repos( $puppetsync_config, $project_dir, $puppetfile, $opts )
  $feature_branch    = getvar('puppetsync_config.jira.parent_issue')

  # ----------------------------------------------------------------------------
  # - [x] Install repos from Puppetfile.repos
  # - [x] git checkout -b BRANCHNAME
  # - [x] ensure jira subtask exists for repo
  # - [x] set up facts
  # --------
  # - [x] puppet apply
  # - [ ] run transformations?  tasks?
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
  # - [ ] validate (e.g., gitlab_ci lint, flag obvious disasters) before committing changes
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
      'repo_paths'    => $repos.map |$target| { $target.vars['repo_path'] },
      '_catch_errors' => false,
    )
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_jira_subtask',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    puppetsync::ensure_jira_subtask_for_each_repo( $ok_repos, $puppetsync_config, $jira_username, $jira_token, $extra_gem_path )
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'apply_puppet_role',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    apply( $ok_repos,
      '_description' => "Apply Puppet role '${puppet_role}'",
      '_noop' => false,
      _catch_errors => true,
    ){
      include $puppet_role
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'git_commit_changes',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $commit_message = $puppetsync_config.dig('git','commit_message').lest || {''}
    $ok_repos.map |$target| {
      run_task( 'puppetsync::git_commit', $target,
        'Commit changes with git',
        {
          'repo_path'      => $target.vars['repo_path'],
          'commit_message' => puppetsync::template_git_commit_message($target,$puppetsync_config),
          '_catch_errors'  => true,
        }
      ).first
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_github_fork',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name|
    {
    $repos.filter |$repo| { puppetsync::all_stages_ok($repo) }.map |$target| {
      $results = run_task( 'puppetsync::ensure_github_fork', $target,
        'Ensure our GitHub user has a fork of the upstream repo',
        {
          'github_repo'      => $target.vars['repo_url_path'],
          'github_authtoken' => $github_token.unwrap,
          'extra_gem_path'   => $extra_gem_path,
          '_catch_errors'    => true,
        }
      )
      if $results.ok {
        $target.set_var('user_repo_fork', $results.first.value)
        out::message( "-- GitHub user's repo fork: '${target.vars['user_repo_fork']['user_fork']}'")
      }
      $results.first
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_git_remote',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$target| {
      warning( "\n------------------ user_repo_fork:\n${$target.vars['user_repo_fork'].to_yaml}" )
      $target.set_var('remote_name', 'user_forked_repo')

      $results = run_task( 'puppetsync::ensure_git_remote', $target,
        'Ensure local git repo has a remote for the forked repository',
        {
          'repo_path'     => $target.vars['repo_path'],
          'remote_url'    => $target.vars['user_repo_fork']['ssh_url'],
          'remote_name'   => $target.vars['remote_name'],
          '_catch_errors' => true,
        }
      )
      if !$results.ok {
        out::message( @("END")
          Running puppetsync::ensure_git_remote failed on ${target.name}:
          ${results.first.error.msg}

          ${results.first.error.details}
          END
        )
      }
      $results.first
    }
  }
  # TODO if any repos were forked, wait 5 minutes for GitHub to catch up

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'git_push_to_remote',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$target| {
      $results = run_command(
        "cd '${target.vars['repo_path']}'; git push '${target.vars['remote_name']}' '${feature_branch}' -f",
        $target,
        "Push branch '${feature_branch}' to forked repository",
        { '_catch_errors' => true }
      )
      $results.first
    }
  }

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'ensure_github_pr',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$target| {
      $results = run_task( 'puppetsync::ensure_github_pr', $target,
        'Ensure there is a GitHub PR for this commit',
        {
          'target_repo'      => $target.vars['repo_url_path'],
          'target_branch'    => $target.vars['mod_data']['branch'],
          'fork_branch'      => $feature_branch,
          'commit_message'   => puppetsync::template_git_commit_message($target,$puppetsync_config),
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
          [ "Running puppetsync::ensure_github_pr failed on ${target.name}:",
            $results.first.error.msg,'','', $results.first.error.details,'', ].join("\n")
        )
      }
      $results.first
    }
  }

  puppetsync::output_pipeline_results( $repos, $project_dir, $opts)
}
