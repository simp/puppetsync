function puppetsync::puppetfile_to_repo_targets(
  Stdlib::Absolutepath $puppetfile,
  String[1] $inventory_group,
  Stdlib::Absolutepath $pwd = dirname($puppetfile),
) {
  # read repos from Puppetfile
  # --------------------------------------
  $puppetfile_data = file::read($puppetfile)

  $pf_mods = puppetsync::parse_puppetfile($puppetfile_data)
  $pf_repos = $pf_mods.filter |$mod, $mod_data| { $mod_data['install_path'] == '_repos' }

  # add a localhost targets for each repo
  # --------------------------------------
  warning("\n=== PF_REPOS: (${pf_repos.size})")
  $pf_repos.each |$mod, $mod_data| {
    warning( "% $mod"  )
    warning( "   $mod_data"  )

    $repo_path = "${pwd}/${mod_data['mod_rel_path']}"
    $metadata_json = "${repo_path}/metadata.json"
    $name = $mod_data['name']

    $target = Target.new(
      'name'   => $mod_data['name'],
      'config' => { 'transport' => 'local', },
      'vars'   => { 'mod_data' => $mod_data }
    )
    $target.add_to_group( $inventory_group )
    $target.set_var('repo_path', $repo_path )

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
