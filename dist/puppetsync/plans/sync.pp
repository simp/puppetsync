plan puppetsync::sync(
  TargetSpec           $targets                = get_targets('default'),
  Stdlib::Absolutepath $pwd                    = system::env('PWD'), # FIXME hacky workaround to get PWD; doesn't work on Windows
  Stdlib::Absolutepath $puppetfile             = "${pwd}/Puppetfile",
  Stdlib::Absolutepath $puppetsync_config_path = "${pwd}/puppetsync_planconfig.yaml"
) {
  $puppetsync_config      = loadyaml($puppetsync_config_path)
  out::message( '===== puppetsync::puppetfile_to_repo_targets' ) #########################
  out::message( "===== puppetfile: '${puppetfile}'" ) #########################
  out::message( "===== pwd: '${pwd}'" ) #########################
  $repos = puppetsync::puppetfile_to_repo_targets( $puppetfile, 'repo_targets')
  out::message( 'FFFFF puppetsync::puppetfile_to_repo_targets' ) #########################

  # Report what we've got so far
  out::message( "Targets: ${repos.size}" )
  out::message( "Puppetfile: ${puppetfile}")
  $repos.each |$target| {
    out::message( "Target: ${target.name}" )
    warning( '=============')
    $target.vars.each |$k,$v| {
      warning( "== ${target.name}.vars[ ${k} ]: ${v}" )
    }
  }

  # ----------------------------------------------------------------------------
  # - [x] git checkout -b BRANCHNAME
  # - [ ] ensure jira subtask exists for repo
  # - [ ] run transformations?
  # - [ ] set up facts
  # - [x] puppet apply
  #   - [ ] remove _noop
  # - [ ] commit changes
  # - [ ] push changes
  # - [ ] PR changes (fork repos, if necessary)
  # ----------------------------------------------------------------------------
  warning( "\n\n==  \$puppetsync_config: ${puppetsync_config}" )
  return run_task(
    'puppetsync::checkout_modules_to_new_branch',
    'localhost',
    'branch'     => $puppetsync_config['jira']['parent_issue'],
    'repo_paths' => $repos.map |$target| { $target.vars['repo_path'] }
  )

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
