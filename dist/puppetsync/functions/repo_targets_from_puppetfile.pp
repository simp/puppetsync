function puppetsync::repo_targets_from_puppetfile(
  Stdlib::Absolutepath $puppetfile,
  String[1] $inventory_group,
  Stdlib::Absolutepath $project_dir = dirname($puppetfile),
  Stdlib::Httpurl $github_url       = 'https://github.com',
) {
  # read repos from Puppetfile
  # --------------------------------------
  $puppetfile_data = file::read($puppetfile)

  $pf_mods = puppetsync::parse_puppetfile($puppetfile_data)
  $pf_repos = $pf_mods.filter |$mod, $mod_data| { $mod_data['install_path'] == '_repos' }

  # add a localhost Target for each repo
  # --------------------------------------
  warning("\n=== PF_REPOS: (${pf_repos.size})")
  $pf_repos.each |$mod, $mod_data| {
    warning( "% ${mod}"  )
    warning( "   ${mod_data}"  )

    ### == simp-cron.vars[ mod_data ]: {
    ###  git => https://github.com/simp/pupmod-simp-cron,
    ###  branch => master,
    ###  name => simp-cron,
    ###  rel_path => _repos/simp-cron,
    ###  repo_name => pupmod-simp-cron,
    ###  mod_rel_path => _repos/cron,
    ###  mod_name => cron, install_path => _repos}
    $repo_path     = "${project_dir}/${mod_data['mod_rel_path']}"
    $repo_url_path = $mod_data['git'].regsubst('https?://[^/]+/?', '' ,'I')

    $metadata_json = "${repo_path}/metadata.json"
    $name = $mod_data['name']

    $target = Target.new(
      'name'   => $mod_data['name'],
      'config' => { 'transport' => 'local', },
      'vars'   => { 'mod_data' => $mod_data }
    )
    $target.add_to_group( $inventory_group )
    $target.set_var('repo_path', $repo_path )
    $target.set_var('repo_url_path', $repo_url_path )

    if !file::exists($metadata_json) {
      warning( "WARNING: File does not exist: ${metadata_json}" )
    }
    else {
      $module_metadata = loadjson($metadata_json)
      $target.set_var('module_metadata', $module_metadata)
    }
  }
  $repos = get_targets('repo_targets')
  return( $repos )
}
