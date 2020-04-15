
plan puppetsync::stage_test(
  TargetSpec $targets = get_targets('localhost'),
){
  $default_repo_moduledir = '_repos'
  $exclude_repos_from_other_module_dirs = true
  $project_dir = system::env('PWD')
  $puppet_role            = 'role::pupmod_travis_only'
  $puppetfile             = "${project_dir}/Puppetfile.repos"
  $feature_branch = 'SIMP-FOO'
  $repos = puppetsync::repo_targets_from_puppetfile(
    $puppetfile, 'repo_targets', $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )
  if $repos.size == 0 { fail_plan( "No repos found to sync!  Is $puppetfile set up correctly?" ) }

  out::message( "== puppetfile: '${puppetfile}'\n== project_dir: '${project_dir}'" )
  puppetsync::setup_repos_facts( $repos )

  $opts = {} # {'stages' => ['stage_two']}

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'checkout_git_feature_branch_in_each_repo',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage| {
    $r = run_task( 'puppetsync::checkout_git_feature_branch_in_each_repo',
      'localhost',
      "Check out git branch '${feature_branch} in all repos'",
      'branch'        => $feature_branch,
      'repo_paths'    => $ok_repos.map |$target| { $target.vars['repo_path'] },
      '_catch_errors' => false,
    )
    # TODO: map single localhost into repo targets
    # $path_map = Hash($repos.map |$x| { [file::join( $project_dir, ($x.vars.dig('mod_data','mod_rel_path').lest || {'-' }) ), $x] })
    # $forward_map = Hash($r[0].value.map |$k,$v| { [  "${path_map[$k]}", $v ] }
  }

  puppetsync::output_pipeline_results( $repos, $project_dir, 'first' )

  $repos.puppetsync::pipeline_stage(
    # --------------------------------------------------------------------------
    'apply_puppet_role',
    # --------------------------------------------------------------------------
    $opts
  ) |$ok_repos, $stage_name| {
    apply(
      $ok_repos,
      '_description' => "Apply Puppet role '$puppet_role'",
      '_noop' => false,
      _catch_errors => true,
    ){ include $puppet_role }
  }

  puppetsync::output_pipeline_results( $repos, $project_dir, 'final' )
}
