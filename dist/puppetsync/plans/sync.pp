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
  warning( "\n\n==  \$puppetsync_config: ${puppetsync_config}" )

  # ----------------------------------------------------------------------------
  # - [x] git checkout -b BRANCHNAME
  # - [x] ensure jira subtask exists for repo
  # - [ ] run transformations?
  # - [ ] set up facts
  # - [x] puppet apply
  #   - [x] remove _noop
  # - [x] commit changes
  # - [ ] ensure GitHub fork of upstream repo exists
  # - [ ] push changes to user's GitHub fork
  # - [ ] PR changes to upstream repository on GitHub
  #
  # - [ ] feature flag each step (on, off, noop?)
  # - [ ] support --noop
  # - [ ] move templating logic from jira task's ruby code into plan
  # - [ ] spec tests
  # - [ ] move task scripts into files/ and convert tasks into shims
  #   - [ ] goal: make logic in each task easy to smoke test on its own
  # ----------------------------------------------------------------------------

  # ----------------------------------------------------------------------------
  $feature_branch = $puppetsync_config['jira']['parent_issue']
  $checkout_results = run_task( 'puppetsync::checkout_git_feature_branch_in_each_repo', 'localhost',
    "Check out git branch '${feature_branch} in all repos'",
    'branch'        => $feature_branch,
    'repo_paths'    => $repos.map |$target| { $target.vars['repo_path'] },
    '_catch_errors' => false,
  )

  # ----------------------------------------------------------------------------
  $gem_install_results = run_task( 'puppetsync::install_gems', 'localhost',
    'Install required RubyGems on localhost',
    {
      'gem_install_path' => $extra_gem_paths[0],
      '_catch_errors'    => false,
    }
  )

  puppetsync::ensure_jira_subtask_for_each_repo(
    $repos, $puppetsync_config, $jira_username, $jira_token, $extra_gem_paths,
  )

  ### # ----------------------------------------------------------------------------
  ### $apply_results = apply(
  ###   $repos,
  ###   '_description' => "Apply Puppet role '$puppet_role'",
  ###   '_noop' => false,
  ###   _catch_errors => true
  ### ) {
  ###   warning( "\$::repo_path = '${::repo_path}'" )
  ###   warning( "\$::module_metadata = '${::module_metadata}'" )
  ###   warning( "\$::module_metadata['forge_org'] = '${::module_metadata['forge_org']}'" )

  ###   if !defined('$::repo_path'){
  ###     fail ( 'The $::repo_path variable must be defined!  Hint: use `rake apply`' )
  ###   }
  ###   include $puppet_role
  ### }

  # ----------------------------------------------------------------------------
  $repos.each |$target| {
    $subtask_key       = $target.vars['jira_subtask_key']
    $parent_issue      = $puppetsync_config['jira']['parent_issue']
    $commmit_template  = $puppetsync_config['git']['commit_message']
    $component_name    = $target.vars['mod_data']['repo_name']
    $commit_message = $commmit_template.regsubst('%JIRA_SUBTASK%', $subtask_key, 'G' ).regsubst('%JIRA_PARENT_ISSUE%', $parent_issue, 'G').regsubst('%COMPONENT%', $component_name, 'G')

    out::message( "\n-- ${target.name}:\n\n${commit_message}\n\n" )
    ### $target.set_var('git_commit_message', $commit_message )
    $results = run_task(
      'puppetsync::git_commit',
      $target,
      "Commit changes with git",
      {
        'repo_path'      => $target.vars['repo_path'],
        'commit_message' => $commit_message,
        '_catch_errors'  => false,
      }
    )
    unless $results.ok {
      $msg = "Running puppetsync::git_commit failed on ${target.name}:\n${results.first.error.msg}\n\n${results.first.error.details}\n"
      out::message($msg)
      fail("$msg") }
  }


}
