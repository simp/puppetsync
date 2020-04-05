function puppetsync::repo_targets_from_puppetfile(
  Stdlib::Absolutepath $puppetfile,
  String[1] $inventory_group,
  String[1] $default_moduledir                  = '_repos',
  Boolean $exclude_repos_from_other_module_dirs = true,
  Stdlib::Absolutepath $project_dir             = dirname($puppetfile),
) {
  # read repos from Puppetfile
  # --------------------------------------
  $puppetfile_data = file::read($puppetfile)

  $pf_mods = puppetsync::parse_puppetfile($puppetfile_data, $default_moduledir)

  $pf_nondefault_moduledir_repos = $pf_mods.filter |$mod, $mod_data| { $mod_data['install_path'] != $default_moduledir }
  if !$pf_nondefault_moduledir_repos.empty {
    #  {_foo/simp-acpid => {git => https://github.com/simp/pupmod-simp-acpid, branch => master, name => simp-acpid, rel_path => _foo/simp-acpid, repo_name => pupmod-simp-acpid, mod_rel_path => _foo/acpid, mod_name => acpid, install_path => _foo}}

    warning( "====== WARNING: found repos with moduledir other than '$default_moduledir':\n${pf_nondefault_moduledir_repos.map |$k,$v|{ "  - ${v['name']}:\t${k}" }.join("\n")}\n\n ")
  }

  if $exclude_repos_from_other_module_dirs {
    if !$pf_nondefault_moduledir_repos.empty {
      warning( "====== WARNING: REJECTING the non-default moduledir repos, because \$exclude_repos_from_other_module_dirs=true" )
    }
    $pf_repos = $pf_mods.filter |$mod, $mod_data| { $mod_data['install_path'] == $default_moduledir }
  } else {
    $pf_repos = $pf_mods
  }



  # add a localhost Target for each repo
  # --------------------------------------
  warning("\n=== PF_REPOS: (${pf_repos.size})")
  $pf_repos.each |$mod, $mod_data| {
    warning( "% ${mod}"  )
    warning( "   ${mod_data}"  )

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
