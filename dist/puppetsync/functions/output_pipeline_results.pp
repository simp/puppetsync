function puppetsync::output_pipeline_results(
  TargetSpec $repos,
  Stdlib::Absolutepath $project_dir,
  ### String  $extra_label = '',
  ### String[1]  $report_timestamp = Timestamp().strftime('%F_%T').regsubst(/:|-/,'','G')
){
  out::message( [
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
  ### $report_prefix = "${project_dir}/puppetsync__sync"

  ### $summary_path = "${report_prefix}.summary.${report_timestamp}${extra_label}.txt"
  ### file::write($summary_path, $repos.puppetsync::summarize_repos_pipeline_results)
  ### out::message("\nWrote sync summary to ${summary_path}\n")

  ### $report_path = "${report_prefix}.report.${report_timestamp}${extra_label}.yaml"
  ### file::write($report_path, $repos.to_yaml)
  ### out::message("\nWrote repos data ${report_path}\n")

  $failures = $repos.map |$k,$x| { $x.vars['puppetsync_stage_results'].filter |$x, $y| { $y['ok'] == false } }
  unless $failures.all |$x| { $x.empty } {
    $f_hashes = $failures.map |$k,$v| {
      $pairs = $v.keys.map |$key| {
        $e = $v.dig($key,'data')
        [
          "${e['target']}: ${key}",
          {'stage'=>$key } +
            $e.filter |$x,$y| { $x in ['action', 'object'] } +
            $e.dig('value','_error').lest||{{}}.filter |$x,$y| { $x in ['kind','msg']  }
        ]
      }
      Hash($pairs)
    }.reduce({})|$m,$v|{$m+$v}

    out::message( "===== ERRORS (${f_hashes.values.count}): \n\n" )
    out::message( $f_hashes.map |$k,$v| {
      $banner = "=== ${k}".format::colorize('fatal')
      $msg = "${v['action']} ${v['object']} (${v['kind']}):\n${v['msg']}".format::colorize('warning')
      "${banner}\n\n${msg}"
    }.join("\n\n\n") )
    fail_plan( 'Plan complete: failures occured', 'puppetsync--plan-errors', $f_hashes )
  }
}
