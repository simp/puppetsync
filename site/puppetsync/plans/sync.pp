plan puppetsync::sync(
  TargetSpec $targets = get_targets('default'),
  $pwd = system::env('PWD'),                           # FIXME hacky workaround to get PWD
) {

  # read repos from Puppetfile
  # --------------------------------------
  $puppetfile = "${pwd}/Puppetfile"
  $puppetfile_data = file::read($puppetfile)
  ###   $session_data = loadyaml("${pwd}/puppetsync_planconfig.yaml")
  ### warning("=== YAML REPOS: $session_data['repos']")

  $pf_mods = puppetsync::parse_puppetfile($puppetfile_data)
  $pf_repos = $pf_mods.filter |$mod, $mod_data| { $mod_data['install_path'] == '_repos' }

  # add a localhost targets for each repo
  # --------------------------------------
  warning("\n=== PF_REPOS: (${pf_repos.size})")
  $pf_repos.each |$mod, $mod_data| {
    warning( "% $mod"  )
    warning( "   $mod_data"  )
    $target = Target.new(
      'name'   => $mod_data['name'],
      'config' => { 'transport' => 'local', },
      'vars'   => $mod_data
    )
    $target.add_to_group('repo_targets')
    $target.set_var('PT_message', $mod_data['name'])
  }

  $repos = get_targets('repo_targets')
  out::message( "Targets: ${repos.size}" )
  out::message( "Puppetfile: ${puppetfile}")
  $repos.each |$target| {
    out::message( "Target: ${target.name}" )
    warning( '=============')
    warning($target.vars)
  } 

  # git checkout branch
  # ensure jira subtask
  # run transformations?
  # puppet apply


  #  return run_command('/usr/bin/date', 'repo_targets' )
  return run_task('puppetsync::test', 'repo_targets')
}
