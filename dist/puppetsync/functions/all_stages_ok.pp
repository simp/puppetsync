# Return true if all of a repo Target's stages have an 'ok' status
# @param repo The repo to check
# @return [Boolean]
function puppetsync::all_stages_ok( Target $repo ) {
  $repo.vars['puppetsync_stage_results'].all |$k,$v| { $v['ok'] }
}
