plan puppetsync::sync(
  TargetSpec           $targets                = get_targets('default'),
  String[1]            $puppet_role            = 'role::pupmod_travis_only',
  String[1]            $jira_username          = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token             = Sensitive(system::env('JIRA_API_TOKEN')),
  Stdlib::Absolutepath $pwd                    = system::env('PWD'), # FIXME hacky workaround to get PWD; doesn't work on Windows
  Stdlib::Absolutepath $puppetfile             = "${pwd}/Puppetfile",
  Stdlib::Absolutepath $puppetsync_config_path = "${pwd}/puppetsync_planconfig.yaml",
  Array[Stdlib::Absolutepath] $extra_gem_paths = ["${pwd}/gems"]
) {
  $puppetsync_config      = loadyaml($puppetsync_config_path)
  $repos = puppetsync::puppetfile_to_repo_targets( $puppetfile, 'repo_targets')

  # Report what we've got so far
  out::message( "===== puppetfile: '${puppetfile}'" ) #########################
  out::message( "===== pwd: '${pwd}'" ) #########################
  ###out::message( "Puppetfile: ${puppetfile}")
  out::message( "Targets: ${repos.size}" )
  $repos.each |$idx, $target| {
    out::message( "  [${idx}]: ${target.name}" )
    warning( '=============')
    $target.vars.each |$k,$v| {
      warning( "== ${target.name}.vars[ ${k} ]: ${v}" )
    }
  }

  # ----------------------------------------------------------------------------
  # - [x] git checkout -b BRANCHNAME
  # - [x] ensure jira subtask exists for repo
  # - [ ] run transformations?
  # - [ ] set up facts
  # - [x] puppet apply
  #   - [ ] remove _noop
  # - [ ] commit changes
  # - [ ] push changes
  # - [ ] PR changes (fork repos, if necessary)
  # ----------------------------------------------------------------------------
  warning( "\n\n==  \$puppetsync_config: ${puppetsync_config}" )

  $feature_branch = $puppetsync_config['jira']['parent_issue']
  $checkout_results = run_task(
    'puppetsync::checkout_git_feature_branch_in_each_repo',
    'localhost',
    "Check out git branch '${feature_branch} in all repos'",
    'branch'     => $feature_branch,
    'repo_paths' => $repos.map |$target| { $target.vars['repo_path'] }
  )

  puppetsync::ensure_jira_subtask_for_each_repo(
    $repos, $puppetsync_config, $jira_username, $jira_token, $extra_gem_paths,
  )

  $apply_results = apply(
    $repos,
    '_description' => "Apply Puppet role '$puppet_role'",
    '_noop' => false,
    _catch_errors => true
  ) {
    warning( "\$::repo_path = '${::repo_path}'" )
    warning( "\$::module_metadata = '${::module_metadata}'" )
    warning( "\$::module_metadata['forge_org'] = '${::module_metadata['forge_org']}'" )

    if !defined('$::repo_path'){
      fail ( 'The $::repo_path variable must be defined!  Hint: use `rake apply`' )
    }
    include $puppet_role
  }

  return $apply_results
  #return run_task('puppetsync::test', 'repo_targets')
}
