# Update assets across multiple git repos using Bolt tasks and Puppet
#
# Supports workflow tasks, like:
#   - Ensuring a Jira subtask exists for each issue
#   - Ensuring a GitHub user has fork of the upstream repo
#   - Submitting PRs exists repos/submitting PRs on GitHub
#
# Files:
#   - Puppetfile.repos:           Defines repos to clone and update
#   - puppetsync_planconfig.yaml: Defines settings for this update
#
# @summary Update assets across multiple git repos using Bolt tasks and Puppet
#
# @usage
#   bolt plan run puppetsync::sync
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
# @param puppetfile
#   (Default: `${project_dir}/Puppetfile.repos`)
#   Puppetfile that defines the repos to update
#
# @author Chris Tessmer <chris.tessmer@onyxpoint.com>
#
# ------------------------------------------------------------------------------
plan puppetsync::sync(
  TargetSpec           $targets                = get_targets('default'),
  String[1]            $puppet_role            = 'role::pupmod_travis_only',
  Stdlib::Absolutepath $project_dir            = system::env('PWD'), # FIXME make a function? (hacky workaround to get PWD; doesn't work on Windows?)
  Stdlib::Absolutepath $puppetfile             = "${project_dir}/Puppetfile.repos",
  Stdlib::Absolutepath $puppetsync_config_path = "${project_dir}/puppetsync_planconfig.yaml",
  Array[Stdlib::Absolutepath] $extra_gem_paths = ["${project_dir}/.gems"], ###
  String[1]            $jira_username          = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token             = Sensitive(system::env('JIRA_API_TOKEN')),
  String[1]            $github_user            = system::env('GITHUB_USER'),
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  String[1]            $default_repo_moduledir = '_repos',
  Boolean              $exclude_repos_from_other_module_dirs = true,
) {
  $puppetsync_config = loadyaml($puppetsync_config_path)
  $feature_branch    = $puppetsync_config['jira']['parent_issue']

  $repos = puppetsync::repo_targets_from_puppetfile(
    $puppetfile, 'repo_targets', $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )
  if $repos.size == 0 { fail_plan( "No repos found to sync!  Is $puppetfile set up correctly?" ) }

  out::message( "== puppetfile: '${puppetfile}'\n== project_dir: '${project_dir}'" )
  out::message(puppetsync::summarize_repo_targets($repos))
  warning(puppetsync::summarize_repo_targets($repos,true))
  warning( "\n\n==  \$puppetsync_config:\n${puppetsync_config.to_yaml.regsubst('^','    ','G')}" )

  puppetsync::install_puppetfile(
    $project_dir, $puppetfile, $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )

  puppetsync::setup_repos_facts( $repos )

  # ----------------------------------------------------------------------------
  # - [x] Install repos from Puppetfile.repos
  # - [x] git checkout -b BRANCHNAME
  # - [x] ensure jira subtask exists for repo
  #   - [ ] detect closed JIRA subtask for same issue and (by default) refuse to open a new one
  # - [x] set up facts
  # --------
  # - [ ] run transformations?
  # - [x] puppet apply
  # - [ ] run transformations?
  # - [ ] (stretch goal) validate changes (e.g., gitlab_ci lint, flag obvious disasters)
  # -------
  # - [x] commit changes
  # - [x] ensure GitHub fork of upstream repo exists
  # - [x] ensure a remote exists in the local git repo for the forked GitHub repo
  # - [x] push changes to user's GitHub fork
  # - [x] PR changes to upstream repository on GitHub
  #   - [ ] detect merged PR for same issue and (by default) refuse to open a new one
  #
  # - [ ] error catching to filter out repos with problems
  #   - [ ] report at the end
  # - [ ] feature flag each step (on, off, noop?)
  # - [ ] support --noop
  # - [x] move task scripts into files/ and convert tasks into shims
  #   - [x] goal: make logic in each task easy to smoke test on its own
  # - [ ] move templating logic from jira task's ruby code into plan logic
  # - [ ] push changes using HTTPS basic auth + the GitHub token (CI friendly)
  # - [ ] spec tests
  # ----------------------------------------------------------------------------


  # ----------------------------------------------------------------------------
  $checkout_results = run_task( 'puppetsync::checkout_git_feature_branch_in_each_repo', 'localhost',
    "Check out git branch '${feature_branch} in all repos'",
    'branch'        => $feature_branch,
    'repo_paths'    => $repos.map |$target| { $target.vars['repo_path'] },
    '_catch_errors' => false,
  )

  # ----------------------------------------------------------------------------
  $gem_install_results = run_task( 'puppetsync::install_gems', 'localhost',
    'Install required RubyGems on localhost',
    {
      'path'          => $extra_gem_paths[0],
      'gems'          => ["jira-ruby:~> 2.0", "octokit:~> 4.18"],
      '_catch_errors' => false,
    }
  )

  puppetsync::ensure_jira_subtask_for_each_repo(
    $repos, $puppetsync_config, $jira_username, $jira_token, $extra_gem_paths,
  )

  puppetsync::record_stage_results(
  # ----------------------------------------------------------------------------
    'apply_puppet_role',
  # ----------------------------------------------------------------------------
    apply(
      $repos.filter |$repo| { puppetsync::all_stages_ok($repo) },
      '_description' => "Apply Puppet role '$puppet_role'",
      '_noop' => false,
      _catch_errors => true,
    ){ include $puppet_role }
  )

  puppetsync::record_stage_results(
    # --------------------------------------------------------------------------
    'git_commit_changes',
    # --------------------------------------------------------------------------
    $repos.filter |$repo| { puppetsync::all_stages_ok($repo) }.map |$target| {
      run_task( 'puppetsync::git_commit', $target,
        "Commit changes with git",
        {
          'repo_path'      => $target.vars['repo_path'],
          'commit_message' => puppetsync::template_git_commit_message($target,$puppetsync_config),
          '_catch_errors'  => true,
        }
      )
    }
  )

  puppetsync::record_stage_results(
    # --------------------------------------------------------------------------
    'ensure_github_fork',
    # --------------------------------------------------------------------------
    $repos.filter |$repo| { puppetsync::all_stages_ok($repo) }.map |$target| {
      $results = run_task( 'puppetsync::ensure_github_fork', $target,
        'Ensure our GitHub user has a fork of the upstream repo',
        {
          'github_repo'      => $target.vars['repo_url_path'],
          'github_user'      => $github_user,
          'github_authtoken' => $github_token.unwrap,
          'extra_gem_paths'  => $extra_gem_paths,
          '_catch_errors'    => false,
        }
      )
      if $results.ok {
        $target.set_var('user_repo_fork', $results.first.value)
        out::message( "-- GitHub user's repo fork: '${target.vars['user_repo_fork']['user_fork']}'")
      }
      $results.first
    }
  )

  puppetsync::record_stage_results(
    # --------------------------------------------------------------------------
    'ensure_git_remote',
    # --------------------------------------------------------------------------
    $repos.filter |$repo| { puppetsync::all_stages_ok($repo) }.map |$target| {
      warning( "\n------------------ user_repo_fork:\n${$target.vars['user_repo_fork'].to_yaml}\n------------------\n")
      $target.set_var('remote_name', 'user_forked_repo')

      $results = run_task( 'puppetsync::ensure_git_remote', $target,
        'Ensure local git repo has a remote for the forked repository',
        {
          'repo_path'     => $target.vars['repo_path'],
          'remote_url'    => $target.vars['user_repo_fork']['ssh_url'],
          'remote_name'   => $target.vars['remote_name'],
          '_catch_errors' => false,
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
  )

  puppetsync::record_stage_results(
    # --------------------------------------------------------------------------
    'git_push_to_remote',
    # --------------------------------------------------------------------------
    $repos.filter |$repo| { puppetsync::all_stages_ok($repo) }.map |$target| {
      $results = run_command(
        "cd '${target.vars['repo_path']}'; git push '${target.vars['remote_name']}' '${feature_branch}' -f",
        $target,
        "Push branch '${feature_branch}' to forked repository",
        { '_catch_errors' => false }
      )
      $results.first
    }
  )

  puppetsync::record_stage_results(
    # --------------------------------------------------------------------------
    'ensure_github_pr',
    # --------------------------------------------------------------------------
    $repos.filter |$repo| { puppetsync::all_stages_ok($repo) }.map |$target| {
      $results = run_task( 'puppetsync::ensure_github_pr', $target,
        'Ensure there is a GitHub PR for this commit',
        {
          'target_repo'      => $target.vars['repo_url_path'],
          'target_branch'    => $target.vars['mod_data']['branch'],
          'fork_branch'      => $feature_branch,
          'commit_message'   => puppetsync::template_git_commit_message($target,$puppetsync_config),
          'github_user'      => $github_user,
          'github_authtoken' => $github_token.unwrap,
          'extra_gem_paths'  => $extra_gem_paths,
          '_catch_errors'    => false,
        }
      )

      if $results.ok {
        $created_status = $results.first.value['pr_created'] ? {
          true    => ' (just created)',
          default => '',
        }
        out::message( "-- GitHub user's repo pr: '${results.first.value['pr_url']}'${created_status}")
      } else {
        $msg = "Running puppetsync::ensure_github_pr failed on ${target.name}:\n${results.first.error.msg}\n\n${results.first.error.details}\n"
        out::message($msg)
      }
      $results.first
    }
  )

  out::message("time to sort out what happened to $repos")
  debug::break()
}
