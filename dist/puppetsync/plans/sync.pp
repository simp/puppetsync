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

  $repos = puppetsync::repo_targets_from_puppetfile(
    $puppetfile, 'repo_targets', $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )

  if $repos.size == 0 { fail_plan( "No repos found to sync!  Is $puppetfile set up correctly?" ) }

  out::message( "===== puppetfile: '${puppetfile}'\n===== project_dir: '${project_dir}'" )
  out::message(puppetsync::summarize_repo_targets($repos))
  warning(puppetsync::summarize_repo_targets($repos,true))
  warning( "\n\n==  \$puppetsync_config:\n${puppetsync_config.to_yaml.regsubst('^','    ','G')}" )

  $puppetfile_install_results = puppetsync::install_puppetfile(
    $project_dir, $puppetfile, $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )

  puppetsync::setup_repos_facts( $repos )

  # ----------------------------------------------------------------------------
  # - [x] Install repos from Puppetfile.repos
  # - [x] git checkout -b BRANCHNAME
  # - [x] ensure jira subtask exists for repo
  # - [x] set up facts
  # - [ ] run transformations?
  # - [x] puppet apply
  #   - [x] remove _noop
  # - [ ] (stretch) validate changes (e.g., gitlab_ci lint)
  # - [x] commit changes
  # - [x] ensure GitHub fork of upstream repo exists
  # - [x] ensure a remote exists in the local git repo for the forked GitHub repo
  # - [x] push changes to user's GitHub fork
  # - [x] PR changes to upstream repository on GitHub
  #
  # - [ ] feature flag each step (on, off, noop?)
  # - [ ] support --noop
  # - [ ] move templating logic from jira task's ruby code into plan logic
  # - [ ] spec tests
  # - [ ] push changes using HTTPS basic auth + the GitHub token (CI friendly)
  # - [x] move task scripts into files/ and convert tasks into shims
  #   - [x] goal: make logic in each task easy to smoke test on its own
  # ----------------------------------------------------------------------------


  # ----------------------------------------------------------------------------
  $feature_branch = $puppetsync_config['jira']['parent_issue']
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
      'gems'          => ['jira-ruby', 'octokit'],
      '_catch_errors' => false,
    }
  )

  ###  # ----------------------------------------------------------------------------
  ###  puppetsync::ensure_jira_subtask_for_each_repo(
  ###    $repos, $puppetsync_config, $jira_username, $jira_token, $extra_gem_paths,
  ###  )

  # ----------------------------------------------------------------------------
  $apply_results = apply(
    $repos,
    '_description' => "Apply Puppet role '$puppet_role'",
    '_noop' => false,
    _catch_errors => false,
  ) {
    warning( "\$::repo_path = '${::repo_path}'" )
    warning( "\$::module_metadata = '${::module_metadata}'" )
    #warning( "\$::module_metadata['forge_org'] = '${::module_metadata['forge_org']}'" )

    if !defined('$::repo_path'){
      fail ( 'The $::repo_path variable must be defined!  Hint: use `rake apply`' )
    }
    include $puppet_role
  }
  fail_plan("FAIL ON PURPOSE")

  # ----------------------------------------------------------------------------
  $repos.each |$target| {
    $subtask_key       = $target.vars['jira_subtask_key']
    $parent_issue      = $puppetsync_config['jira']['parent_issue']
    $commmit_template  = $puppetsync_config['git']['commit_message']
    $component_name    = $target.vars['mod_data']['repo_name']
    $commit_message = $commmit_template.regsubst('%JIRA_SUBTASK%', $subtask_key, 'G' ).regsubst('%JIRA_PARENT_ISSUE%', $parent_issue, 'G').regsubst('%COMPONENT%', $component_name, 'G')

    ### out::message( "\n-----------\n${target.name}:\n\n${commit_message}\n\n" )
    ### $target.set_var('git_commit_message', $commit_message )

    $git_commit_results = run_task( 'puppetsync::git_commit', $target,
    # --------------
      "Commit changes with git",
      {
        'repo_path'      => $target.vars['repo_path'],
        'commit_message' => $commit_message,
        '_catch_errors'  => true,
      }
    )
    unless $git_commit_results.ok {
      $msg = "!! Running puppetsync::git_commit failed on ${target.name}:\n${git_commit_results.first.error.msg}\n\n${git_commit_results.first.error.details}\n"
      out::message($msg)
      fail_plan($git_commit_results.first.error)
    }

    $ensure_fork_results = run_task( 'puppetsync::ensure_github_fork', $target,
    # --------------
      'Ensure our GitHub user has a fork of the upstream repo',
      {
        'github_repo'      => $target.vars['repo_url_path'],
        'github_user'      => $github_user,
        'github_authtoken' => $github_token.unwrap,
        'extra_gem_paths'  => $extra_gem_paths,
        '_catch_errors'    => false,
      }
    )

    if $ensure_fork_results.ok {
      out::message( "-- GitHub user's repo fork: '${ensure_fork_results.first.value['user_fork']}'")
    } else {
      $msg = "Running puppetsync::ensure_github_fork failed on ${target.name}:\n${ensure_fork_results.first.error.msg}\n\n${ensure_fork_results.first.error.details}\n"
      out::message($msg)
      fail_plan($ensure_fork_results.first.error)
    }
    $user_repo_fork = $ensure_fork_results.first.value
    warning( "\n------------------ user_repo_fork:\n${user_repo_fork}\n------------------\n")
    $remote_name = 'user_forked_repo'

    $ensure_remote_results = run_task( 'puppetsync::ensure_git_remote', $target,
    # --------------
      'Ensure local git repo has a remote for the forked repository',
      {
        'repo_path'     => $target.vars['repo_path'],
        'remote_url'    => $user_repo_fork['ssh_url'],
        'remote_name'   => $remote_name,
        '_catch_errors' => false,
      }
    )
    if !$ensure_remote_results.ok {
      out::message( @("END")
        Running puppetsync::ensure_git_remote failed on ${target.name}:
        ${ensure_remote_results.first.error.msg}

        ${ensure_remote_results.first.error.details}
        END
      )
      fail_plan($ensure_remote_results.first.error)
    }

    $git_push_results = run_command(
    # --------------
      "cd '${target.vars['repo_path']}'; git push '${remote_name}' '${feature_branch}' -f",
      $target,
      "Push branch '${feature_branch}' to forked repository",
      { '_catch_errors' => false }
    )
    warning( "\n------------------ git_push_results:\n${git_push_results}\n------------------\n")

    $ensure_pr_results = run_task( 'puppetsync::ensure_github_pr', $target,
    # --------------
      'Ensure there is a GitHub PR for this commit',
      {
        'target_repo'      => $target.vars['repo_url_path'],
        'target_branch'    => $target.vars['mod_data']['branch'],
        'fork_branch'      => $feature_branch,
        'commit_message'   => $commit_message,
        'github_user'      => $github_user,
        'github_authtoken' => $github_token.unwrap,
        'extra_gem_paths'  => $extra_gem_paths,
        '_catch_errors'    => false,
      }
    )

    if $ensure_pr_results.ok {
      $created_status = $ensure_pr_results.first.value['pr_created'] ? {
        true    => ' (just created)',
        default => '',
      }
      out::message( "-- GitHub user's repo pr: '${ensure_pr_results.first.value['pr_url']}'${created_status}")
    } else {
      $msg = "Running puppetsync::ensure_github_pr failed on ${target.name}:\n${ensure_pr_results.first.error.msg}\n\n${ensure_pr_results.first.error.details}\n"
      out::message($msg)
      fail_plan($ensure_pr_results.first.error)
    }
  }

}
