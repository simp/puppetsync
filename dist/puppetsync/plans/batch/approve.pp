#
plan puppetsync::batch::approve(
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  String[1]            $batchlist              = 'latest',
  String[1]            $config                 = 'latest',
  String[1]            $repolist               = '---',
  Hash                 $batches_config         = lookup('puppetsync::batches_config'),
  Stdlib::Absolutepath $extra_gem_path         = "${project_dir}/.plan.gems",
  Sensitive[String[1]] $github_token           = Sensitive(system::env('GITHUB_API_TOKEN')),
  Hash                 $options                = {},
) {
  $results = $batches_config['repolists'].map |$repolist| {
    out::message("\n==== Running puppetsync for '${repolist}'")
    $result = run_plan( 'puppetsync::approve_github_prs', {
        'targets'           => $targets,
        'project_dir'       => $project_dir,
        'batchlist'         => $batchlist,
        'config'            => $config,
        'repolist'          => $repolist,
        'extra_gem_path'    => $extra_gem_path,
        'github_token'      => $github_token,
        'options'           => $options,
        '_catch_errors'     => true,
      },
    )
    $delay = $batches_config.get('delay').lest || { 300 }
    out::message("\n==== Sleeping ${delay} seconds after running puppetsync for '${repolist}'")
    ctrl::sleep( $delay )
    next($result)
  }
  return( $results )
}
