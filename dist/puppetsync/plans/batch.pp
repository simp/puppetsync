#
plan puppetsync::batch(
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  String[1]            $batchlist              = 'latest',
  String[1]            $config                 = 'latest',
  String[1]            $repolist               = '---',
  Hash                 $batches_config         = lookup('puppetsync::batches_config'),
  Stdlib::Absolutepath $extra_gem_path         = "${project_dir}/.plan.gems",
  String[1]            $jira_username          = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token             = Sensitive(system::env('JIRA_API_TOKEN')),
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  Sensitive[String[1]] $gitlab_token           = Sensitive(system::env('GITLAB_API_TOKEN')),
  Hash                 $options                = {},
) {
  $results = $batches_config['repolists'].map |$repolist| {
    out::message("\n==== Running puppetsync for '${repolist}'")
    $result = run_plan( 'puppetsync', {
        'targets'           => $targets,
        'project_dir'       => $project_dir,
        'batchlist'         => $batchlist,
        'config'            => $config,
        'repolist'          => $repolist,
        'extra_gem_path'    => $extra_gem_path,
        'jira_username'     => $jira_username,
        'jira_token'        => $jira_token,
        'github_token'      => $github_token,
        'gitlab_token'      => $gitlab_token,
        'options'           => $options,
        '_catch_errors'     => true,
      },
    )
    $delay = $batches_config.get('delay').lest || { 300 }
    out::message("\n==== Sleeping ${delay} seconds after running puppetsync for '${repolist}'")
    ctrl::sleep( $delay )
    next($result)
  }
  debug::break()
  return( $results )
}
