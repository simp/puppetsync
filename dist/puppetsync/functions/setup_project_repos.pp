# @ summary Read, clone, add facts, and filter repo Targets from the project's Puppetfile.repos file
#
# @return [Array[Target]] Project repo Targets
function puppetsync::setup_project_repos(
  Hash                 $puppetsync_config,
  Stdlib::Absolutepath $project_dir            = system::env('PWD'),
  Stdlib::Absolutepath $puppetfile             = "${project_dir}/Puppetfile.repos",
  String[1]            $default_repo_moduledir = '_repos',
  Boolean              $exclude_repos_from_other_module_dirs = true,
){
  $pf_repos = puppetsync::repo_targets_from_puppetfile(
    $puppetfile, 'repo_targets', $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )
  if $pf_repos.size == 0 { fail_plan( "No repos found to sync!  Is ${puppetfile} set up correctly?" ) }

  out::message( "== puppetfile: '${puppetfile}'\n== project_dir: '${project_dir}'" )
  warning( "\n\n==  \$puppetsync_config:\n${puppetsync_config.to_yaml.regsubst('^','    ','G')}" )

  puppetsync::install_puppetfile(
    $project_dir, $puppetfile, $default_repo_moduledir, $exclude_repos_from_other_module_dirs
  )

  puppetsync::setup_repos_facts( $pf_repos )
  $repos = puppetsync::filter_permitted_repos( $pf_repos, $puppetsync_config )

  out::message(puppetsync::summarize_repo_targets($repos))
  warning(puppetsync::summarize_repo_targets($repos,true))

  $repos
}
