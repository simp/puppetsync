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

  $pf_mods                = puppetsync::parse_puppetfile($puppetfile_data, $default_moduledir)
  $pf_alt_moduledir_repos = $pf_mods.filter |$mod, $mod_data| {
    $mod_data['install_path'] != $default_moduledir
  }

  if !$pf_alt_moduledir_repos.empty {
    warning( @("END")
      ====== WARNING: found repos with moduledir != '$default_moduledir':
      ${pf_alt_moduledir_repos.map |$k,$v|{ "  - ${v['name']}:\t${k}" }.join("\n")}
    END
  )}

  if $exclude_repos_from_other_module_dirs {
    if !$pf_alt_moduledir_repos.empty {
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

    $name = $mod_data['name']

    $target = Target.new('name' => $mod_data['name'])
    $target.add_to_group( $inventory_group )
    $target.set_var('mod_data', $mod_data )
    $target.set_var('repo_path', $repo_path )
    $target.set_var('repo_url_path', $repo_url_path )

    # Use whatever ruby interpreter the 'localhost' target is using (which is
    # whatever bolt is using) to keep the inventory as cross-platform as
    # possible
    $target.set_config(
      ['local', 'interpreters', '.rb'],
      get_target('localhost').config.dig('local', 'interpreters', '.rb')
    )
  }
  $repos = get_targets($inventory_group)
  return( $repos )
}