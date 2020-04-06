
plan puppetsync::apply(
  TargetSpec           $targets     = get_targets('localhost'),
  Stdlib::Absolutepath $project_dir = system::env('PWD'), # FIXME hacky workaround to get PWD; doesn't work on Windows?
  # Stdlib::Absolutepath $puppetfile             = "${project_dir}/Puppetfile.repos",
  #Stdlib::Absolutepath $puppetsync_config_path = "${project_dir}/puppetsync_planconfig.yaml",
  #String[1]            $default_repo_moduledir = '_repos',
  #Boolean              $exclude_repos_from_other_module_dirs = true,
){

  # ---------- localhost
  $targets[0].set_var('puppetsync', 'test')
  $targets[0].set_var('repo_path', "${system::env('PWD')}/tmp")

  # ---------- named_local_target
  $named_local_target = Target.new( 'name' => 'named_local_target' )
  $named_local_target.add_to_group( 'repo_targets' )
  #$named_local_target.set_var('repo_path', "${system::env('PWD')}/tmp")

  $both_targets = [$targets[0], $named_local_target]
  # =========================================================================

  ### $puppetsync_config          = loadyaml($puppetsync_config_path)
  ### $puppetfile_install_results = run_task( 'puppetsync::puppetfile_install', 'localhost',
  ###   # -------------------------------------------------------------------------
  ###   "Install repos from '${puppetfile}' (default moduledir: '${default_repo_moduledir}')",
  ###   'project_dir'       => $project_dir,
  ###   'puppetfile'        => $puppetfile,
  ###   'default_moduledir' => $default_repo_moduledir,
  ###   '_catch_errors'     => false,
  ### )

  ### $repos = puppetsync::repo_targets_from_puppetfile($puppetfile, 'repo_targets', $default_repo_moduledir, $exclude_repos_from_other_module_dirs)
  ### if $repos.size == 0 { fail_plan( "No repos found to sync!  Is $puppetfile set up correctly?" ) }

  $both_targets.each |$target| {
    $file ="$project_dir/foo.${target.name}.txt"
    out::message( "==== target ${target.name} apply: ($file)" )
    apply(
      $target,
      '_description' => "Test puppet apply",
      '_noop' => false,
      _catch_errors => false
    ){
      warning( "------------------ TARGET: ${target.name}")
      $content =  $target.vars.map |$k,$v| { "\n${target.name}.vars[ ${k} ]: ${v}" }.join("\n\n")
      file{ $file: content => $content }
      ###    warning( "\$::repo_path = '${::repo_path}'" )
      ###    ###warning( "\$::module_metadata = '${::module_metadata}'" )
      ###    ####warning( "\$::module_metadata['forge_org'] = '${::module_metadata['forge_org']}'" )

      ###    if !defined('$::repo_path'){
      ###      fail ( "The \$::repo_path variable must be defined ($::repo_path)!\n          Hints:\n            - install  $puppetfile\n            - make sure $default_repo_moduledir contains the expected repo\n" )
      ###    }
      ###include $puppet_role
    }
  }
}
