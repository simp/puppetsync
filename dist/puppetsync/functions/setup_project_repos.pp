# @ summary Read, clone, add facts, and filter repo Targets from the project's Puppetfile.repos file
#
# @return [Array[Target]] Project repo Targets
function puppetsync::setup_project_repos(
  Hash                 $puppetsync_config,
  Hash                 $repos_config,
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  Hash                 $options                = {},
) >> Array[Target] {
  $opts = {
    'clone_git_repos'        => true,
    'default_repo_moduledir' => '_repos',
    'clear_before_clone'     => true,
    'filter_permitted_repos' => true,
  } + $options
  if $opts.dig('list_pipeline_stages') { return [] }

  $pf_repos = puppetsync::repo_targets_from_repolist(
    $repos_config, 'repo_targets', $project_dir,  $opts['default_repo_moduledir']
  )
  if $pf_repos.size == 0 { fail_plan( 'No repos found to sync!  Is the repolist set up correctly?' ) }

  out::message( "== project_dir: '${project_dir}'" )

  warning( "\n\n==  \$puppetsync_config:\n${puppetsync_config.to_yaml.regsubst('^','    ','G')}" )

  if $opts['clone_git_repos'] {
    $repos_dir = "${project_dir}/${opts['default_repo_moduledir']}"
    if $opts['clear_before_clone'] {
      $ruby_path = get_target('localhost').config['local']['interpreters']['.rb']
      run_command(
        "${ruby_path} -r fileutils -e 'FileUtils.mkdir_p \"${repos_dir}\"; FileUtils.rm_rf(Dir[\"${repos_dir}/*\"])'",
        'localhost'
      )
    }
    $result = parallelize($pf_repos) |$t| {
      # FIXME should this blow away the old directory or git fetch/checkout?
      # TODO make this a task with smarter behavior
      $cmd = "git clone \"${t.vars['mod_data']['git_url']}\" \"${t.vars['repo_path']}\" -b \"${t.vars['mod_data']['branch']}\""
      out::message($cmd)
      run_command($cmd, $t)
    }
  } else {
    warning('')
    warning('== WARNING: **NOT** cloning git repos because $opts["clone_git_repos"] = false!')
    warning('== WARNING: This speeds up the start of plans, and is probably fine outside of a puppetsync.  HOWEVER:')
    warning('== WARNING: * This will stop puppetsync from cloning, adding file-derived facts, and filtering repos (e.g., on project_type)')
    warning("== WARNING: * Among other consequences, all repo's project_type will remain 'unknown'.")
    warning("== WARNING: If things go wrong, make SURE you didn't actually need facts or repo type-filtering!")
    warning('')
  }

  puppetsync::setup_repos_facts( $pf_repos )
  $repos =  $opts['filter_permitted_repos'] ? {
    true    => puppetsync::filter_permitted_repos( $pf_repos, $puppetsync_config ),
    default => $pf_repos,
  }

  if $repos.size == 0 {
    fail_plan( "No repos left to sync after filtering! Do the config's `permitted_project_types` match the repos in the repolist?" )
  }

  out::message(puppetsync::summarize_repo_targets($repos))
  warning(puppetsync::summarize_repo_targets($repos,true))

  $repos
}
