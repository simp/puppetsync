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
      $status = $all_ok ? {
        false   => 'failed',
        default => $repo.vars['puppetsync_unchanged'] ? { true => 'unchanged', default => 'ok' },
      }
      if $colorize {
        case $status {
          'failed': {
            [ format::colorize( $repo.name, 'warning' ), format::colorize('failed','fatal'), format::colorize($stage, 'warning') ]
          }
          'unchanged': {
            [ $repo.name, 'unchanged', $stage ]
          }
          default: {
            [ $repo.name, format::colorize('ok', 'good'), $stage ]
          }
        }
      } else {
        [ $repo.name, $status, $stage ]
      }
    }
  })
}
