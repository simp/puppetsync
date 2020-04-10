function puppetsync::all_stages_ok( Target $repo ) {
  $repo.vars['puppetsync_stage_results'].all |$k,$v| { $v['ok'] }
}
