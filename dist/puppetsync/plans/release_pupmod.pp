# Clone, tag, and push GitHub release for each repo in the repolist
#
# @summary Clone, tag, and push GitHub release for each repo in the repolist
#
# @example
#
#   Run:
#
#      bolt plan run puppetsync::release_pupmod
#
# @param targets
#   The parameter is required to exist, but is unused.
#   All targets are generated as `transport: local` during execution
#
# @param project_dir
#   The bolt project directory (Defaults to `$PWD`)
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
#   A Hash of repos and branches to clone, modify, and PR.
#   By default, this is loaded from Hiera data based on the `config` parameter.
#
# @author Chris Tessmer <chris.tessmer@onyxpoint.com>
#
# ------------------------------------------------------------------------------
plan puppetsync::release_pupmod(
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  String[1]            $batchlist              = '---',
  String[1]            $config                 = 'latest',
  String[1]            $repolist               = 'latest',
  Hash                 $puppetsync_config      = lookup('puppetsync::plan_config'),
  Hash                 $repos_config           = lookup('puppetsync::repos_config'),
  Hash                 $options                = {},
) {
  $opts = {
    'clone_git_repos'          => true, # Need to clone repos in order to tag and push
    'filter_permitted_repos'   => true, # Assume all matching PRs are permitted repo types
    'github_api_delay_seconds' => 1,
  } + getvar('puppetsync_config.puppetsync.plans.release_pupmod').lest || {{}} + $options

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
    'release_pupmod',
    # ---------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    $ok_repos.map |$repo| {

      $metadata_json_path = $repo.facts['project_type'] ? {
        'pupmod' => "${repo.vars['repo_path']}/metadata.json",
        default  => fail("ERROR: This plan can only release pupmods - ${repo.vars['repo_name']} is type '${repo.facts['project_type']}'"),
      }

      $result = run_task( 'puppetsync::release_pupmod', $repo,
        "Clone, tag, and push git release for repo ${repo.vars['mod_data']['repo_name']} (branch: ${repo.vars['mod_data']['branch']})",
        'filename'                => $metadata_json_path,
        '_catch_errors'           => true,
      ).first

      unless $result.ok {
        $error ="ERROR: ${repo.name}:\n\t(${result.error.kind})\n${result.error.msg.regsubst('^',"\t",'G')}\n"
        out::message( $error )
        warning( $error )
      }
      ctrl::sleep($opts['github_api_delay_seconds'])
      $result
    }
  }

  puppetsync::output_pipeline_results( $repos, $project_dir )
}
