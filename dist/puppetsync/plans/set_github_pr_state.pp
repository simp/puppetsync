# Flip all of a puppetsync session's open GitHub PRs between draft and
# ready-for-review
#
# Like the approve/merge plans, the session's open PRs are enumerated by
# feature branch (+ author) — no repolist or inventory snapshot needed.
#
# @summary Mark all of a puppetsync session's open PRs as draft or ready
#
# @example Mark the current session's PRs as drafts
#
#   1. Set environment var `GITHUB_API_TOKEN`
#   2. Run:
#
#      bolt plan run puppetsync::set_github_pr_state state=draft
#
# @example Flip them back when the session is ready to harvest
#
#      bolt plan run puppetsync::set_github_pr_state state=ready
#
# @param targets
#   The parameter is required to exist, but is unused.
#   All targets are generated as `transport: local` during execution
#
# @param state
#   The desired state for every open PR in the session: 'draft' or 'ready'
#
# @param project_dir
#   The bolt project directory (Defaults to `$PWD`)
#
# @param config
#   Names the sync-session settings file under `data/sync/configs/`
#   (Default: 'latest')
#
# @param repolist
#   Unused (kept for CLI parity with the other plans)
#
# @param puppetsync_config
#   A Hash of puppetsync settings for the session; provides the feature
#   branch, GitHub org, and PR user. By default, loaded from Hiera based
#   on the `config` parameter.
#
# @param pr_user
#   The GitHub user that submitted the PRs (Default: `github.pr_user` from
#   the session config)
#
# @param github_token
#   GitHub API token (Default: environment variable `$GITHUB_API_TOKEN`)
#
# @param extra_gem_path
#   Path to a gem path with extra gems the bolt interpreter needs to run
#   some of the Ruby tasks (Default: `${project_dir}/.plan.gems`)
#
# @param options
#   Hash of options to tweak local settings in the plan; merged over
#   `puppetsync::plan_config` > `plans` > `set_github_pr_state`
#
# ------------------------------------------------------------------------------
plan puppetsync::set_github_pr_state(
  Enum['draft','ready'] $state,
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  String[1]            $batchlist              = '---',
  String[1]            $config                 = 'latest',
  String[1]            $repolist               = 'latest',
  Hash                 $puppetsync_config      = lookup('puppetsync::plan_config'),
  String[1]            $pr_user                = $puppetsync_config.dig('github','pr_user').lest || { undef },
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  Stdlib::Absolutepath $extra_gem_path         = "${project_dir}/.plan.gems",
  Hash                 $options                = {},
) {
  $opts = {
    'clone_git_repos'          => false, # Don't need clones to flip PR states
    'filter_permitted_repos'   => false, # Assume all matching PRs are permitted repo types
    'github_api_delay_seconds' => 1,
  } + getvar('puppetsync_config.puppetsync.plans.set_github_pr_state').lest || {{}} + $options

  $feature_branch = getvar('puppetsync_config.git.feature_branch')
  $github_org = getvar('puppetsync_config.github.org').lest || { 'simp' }

  if $opts.dig('list_pipeline_stages') {
    $repos = []
  } else {
    $listing = run_task('puppetsync::list_github_prs', 'localhost',
      "Enumerate open PRs on branch '${feature_branch}' in org '${github_org}'",
      {
        'org'              => $github_org,
        'head_branch'      => $feature_branch,
        'author'           => $pr_user,
        'github_authtoken' => $github_token.unwrap,
      }
    ).first.value

    $repos = puppetsync::repo_targets_from_prs($listing['prs'])
    out::message( sprintf(
      "== %d open PRs by '%s' on branch '%s' in org '%s' to mark as '%s'",
      $repos.size, $pr_user, $feature_branch, $github_org, $state,
    ))
    if $repos.size == 0 {
      fail_plan("No open PRs found on branch '${feature_branch}' in org '${github_org}' (author: ${pr_user})")
    }
  }

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
        'gems'          => ['octokit:~> 4.18'],
        '_catch_errors' => false,
      }
    )
  }

  $repos.puppetsync::pipeline_stage(
    # ---------------------------------------------------------------------------
    'set_github_pr_state_for_each_repo',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$target| {
      $result = run_task( 'puppetsync::set_github_pr_state', $target,
        "Mark PR for branch '${feature_branch}' as ${state}",
        'target_repo'      => $target.vars['repo_url_path'],
        'target_branch'    => $target.vars.dig('mod_data','branch'),
        'fork_user'        => $pr_user,
        'fork_branch'      => $feature_branch,
        'state'            => $state,
        'github_authtoken' => $github_token.unwrap,
        'extra_gem_path'   => $extra_gem_path,
        '_catch_errors'    => true,
      ).first
      unless $result.ok {
        $error ="ERROR: ${target.name}:\n\t(${result.error.kind})\n${result.error.msg.regsubst('^',"\t",'G')}\n"
        out::message( $error )
        warning( $error )
      }
      ctrl::sleep($opts['github_api_delay_seconds'])
      $result
    }
  }

  puppetsync::output_pipeline_results( $repos, $project_dir )
}
