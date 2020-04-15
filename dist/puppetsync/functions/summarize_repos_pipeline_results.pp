# @summary Returns a formatted table of pipeline results for each repo Target
# @return [String] Formatted table of pipeline results + final stage run for each repo Target
function puppetsync::summarize_repos_pipeline_results(
  TargetSpec $repos,
  Boolean    $colorize = false,
) {
  format::table({
    title => 'Results',
    head  => [ 'Repo', 'Result', 'Final Stage' ],
    rows  => $repos.map |$repo| {
      $all_ok = $repo.vars['puppetsync_stage_results'].all |$k,$v| { $v['ok'] }
      $stage = $repo.vars['puppetsync_stage_results'].keys[-1].lest || {  $repo.vars['puppetsync_stage_results'].count }
      if $colorize {
        [
          $all_ok ? { true => $repo.name, default => format::colorize( $repo.name, 'warning' ) },
          $all_ok ? { true => format::colorize('ok', 'good'), default => format::colorize('failed','fatal') },
          $all_ok ? { true =>  $stage, default => format::colorize($stage, 'warning') },
        ]
      } else {
        [ $repo.name, $all_ok ? { true => 'ok', default => 'failed' }, $stage ]
      }
    }
  })
}
