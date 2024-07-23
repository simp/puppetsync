# Approve multiple GitHub PRs for a puppetsync sync
#
# @summary Approve GitHub PRs for all repos in a puppetsync sync
#
# @example
#
#   1. Set environment var `GITHUB_API_TOKEN`
#   2. Run:
#
#      bolt plan run puppetsync::approve
#
# @param targets
#   The parameter is required to exist, but is unused.
#   All targets are generated as `transport: local` during execution
#
# @param approval_message
#   A message to go along with the approval (Default: `:+1: :ghost:`)
#
# @param project_dir
#   The bolt project directory (Defaults to `$PWD`)
#
# @param puppetfile
#   A special Puppetfile with :git repos to clone, update, and PR
#   (Default: `${project_dir}/Puppetfile.repos`)
#
# @param puppetsync_config_path
#   Path to a YAML file with settings for a specific puppetsync session
#   See the project README.md for an example.
#   (Default: `${project_dir}/puppetsync_planconfig.yaml`)
#
# @param extra_gem_path
#   Path to a gem path with extra gems the bolt interpreter will to run
#   some of the Ruby tasks.
#   (Default: `${project_dir}/.plan.gems`)
#
# @author Chris Tessmer <chris.tessmer@onyxpoint.com>
#
# ------------------------------------------------------------------------------
plan puppetsync::approve_github_prs (
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  String[1]            $batchlist              = '---',
  String[1]            $config                 = 'latest',
  String[1]            $repolist               = 'latest',
  Hash                 $puppetsync_config      = lookup('puppetsync::plan_config'),
  Hash                 $repos_config           = lookup('puppetsync::repos_config'),
  String[1]            $pr_user                = $puppetsync_config.dig('github','pr_user').lest || { undef },
  String[1]            $approval_message       = $puppetsync_config.dig('github','approval_message').lest || { ':+1: :ghost:' },
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  Stdlib::Absolutepath $extra_gem_path         = "${project_dir}/.plan.gems",
  Hash                 $options                = {},
) {
  $opts = {
    'clone_git_repos'          => false, # Don't need to clone repos just to approve PRs
    'filter_permitted_repos'   => false, # Assume all matching PRs are permitted repo types
    'github_api_delay_seconds' => 1,
  } + getvar('puppetsync_config.puppetsync.plans.approve_github_prs').lest || {{} } + $options

  $repos = puppetsync::setup_project_repos(
    $puppetsync_config,
    $repos_config,
    $project_dir,
    {
      'clone_git_repos'        => $opts['clone_git_repos'],
      'filter_permitted_repos' => $opts['filter_permitted_repos'],
    }
  )

  $feature_branch = getvar('puppetsync_config.git.feature_branch')

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
    'approve_github_pr_for_each_repo',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$target| {
      $result = run_task( 'puppetsync::approve_github_pr', $target,
        "Approve git branch '${feature_branch}'",
        'target_repo'      => $target.vars['repo_url_path'],
        'target_branch'    => $target.vars.dig('mod_data','branch'),
        'fork_user'        => $pr_user,
        'fork_branch'      => $feature_branch,
        'approval_message' => $approval_message,
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
