# Prints a summary of all results and fails the plan with structured data if there were problems
# @return [void]
function puppetsync::output_pipeline_results(
  TargetSpec $repos,
  Stdlib::Absolutepath $project_dir,
  Hash $project_opts = {},
) {
  if $project_opts.dig('list_pipeline_stages') {
    warning( 'Project is listing pipeline stages; no results to output' )
    return({})
  }
  out::message(
    [
      '',
      '================================================================================',
      "                                    FINIS                                       ",
      '================================================================================',
      "time to sort out what happened to:\n\t${repos}",
      '--------------------------------------------------------------------------------',
      '',
    ].join("\n")
  )

  out::message("\n${repos.puppetsync::summarize_repos_pipeline_results(true)}\n\n")

  $failures = $repos.map |$k,$x| { $x.vars['puppetsync_stage_results'].filter |$x, $y| { $y['ok'] == false } }
  unless $failures.all |$x| { $x.empty } {
    $f_hashes = $failures.map |$k,$v| {
      $pairs = $v.keys.map |$key| {
        $e = $v.dig($key,'data')
        [
          "${e['target']}: ${key}",
          { 'stage'=> $key } +
          $e.filter |$x,$y| { $x in ['action', 'object'] } +
          $e.dig('value','_error').lest|| {{} }.filter |$x,$y| { $x in ['kind','msg'] }
        ]
      }
      Hash($pairs)
    }.reduce({})|$m,$v| { $m+$v }

    out::message( "===== ERRORS (${f_hashes.values.count}): \n\n" )
    out::message( $f_hashes.map |$k,$v| {
        $banner = "=== ${k}".format::colorize('fatal')
        $msg = "${v['action']} ${v['object']} (${v['kind']}):\n${v['msg']}".format::colorize('warning')
        "${banner}\n\n${msg}"
    }.join("\n\n\n") )
    fail_plan( 'Plan complete: failures occured', 'puppetsync--plan-errors', $f_hashes )
  }
}
