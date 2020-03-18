plan puppetsync::sync(
  TargetSpec $targets = get_targets('default'),
  $pwd = system::env('PWD'), # FIXME hacky workaround to get PWD; doesn't work on Windows
) {

  # read repos from Puppetfile
  # --------------------------------------
  $puppetfile = "${pwd}/Puppetfile"
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
    $target.add_to_group('repo_targets')
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
  out::message( "Targets: ${repos.size}" )
  out::message( "Puppetfile: ${puppetfile}")
  $repos.each |$target| {
    out::message( "Target: ${target.name}" )
    warning( '=============')
    $target.vars.each |$k,$v| {
      warning( "== ${target.name}.vars[ ${k} ]: ${v}" )
    }
  }

  # - [ ] git checkout -b BRANCHNAME
  # - [ ] ensure jira subtask exists for repo
  # - [ ] run transformations?
  # - [ ] puppet apply
  # - [ ] set up facts

  #  return run_command('/usr/bin/date', 'repo_targets' )
  return apply(
    'repo_targets',
    '_description' => "Apply Puppet role ",
    '_noop' => true,
    _catch_errors => true
  ) {
    warning( "\$::repo_path = '${::repo_path}'" )
    warning( "\$::module_metadata = '${::module_metadata}'" )
    warning( "\$::module_metadata['forge_org'] = '${::module_metadata['forge_org']}'" )

    if !defined('$::repo_path'){
      fail ( 'The $::repo_path variable must be defined!  Hint: use `rake apply`' )
    }

    lookup('classes', {'value_type'    => Array[String],
                       'merge'         => 'unique',
                       'default_value' => [],
                      }).include
  }
  #return run_task('puppetsync::test', 'repo_targets')
}
