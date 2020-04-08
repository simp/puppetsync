function puppetsync::install_puppetfile(
  Stdlib::Absolutepath $project_dir,
  Stdlib::Absolutepath $puppetfile,
  String[1]            $default_repo_moduledir,
  Boolean              $exclude_repos_from_other_module_dirs
){
  run_task( 'puppetsync::puppetfile_install', 'localhost',
    "Install repos from '${puppetfile}' (default moduledir: '${default_repo_moduledir}')",
    'project_dir'       => $project_dir,
    'puppetfile'        => $puppetfile,
    'default_moduledir' => $default_repo_moduledir,
    '_catch_errors'     => false,
  )
}
