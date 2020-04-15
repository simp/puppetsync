function puppetsync::output_pipeline_results(
  TargetSpec $repos,
  Stdlib::Absolutepath $project_dir,
  String[1]  $extra_label = '',
  String[1]  $report_timestamp = Timestamp().strftime('%F_%T').regsubst(/:|-/,'','G')
){
  out::message( [
    "================================================================================",
    "                                    FINIS                                       ",
    "================================================================================",
    "time to sort out what happened to:\n\t${repos}",
    "--------------------------------------------------------------------------------",
    ].join("\n")
  )

  out::message("\n${repos.puppetsync::summarize_repos_pipeline_results(true)}\n\n")
  $report_prefix = "${project_dir}/puppetsync__sync"

  $summary_path = "${report_prefix}.summary.${report_timestamp}${extra_label}.txt"
  file::write($summary_path, $repos.puppetsync::summarize_repos_pipeline_results)
  out::message("\nWrote sync summary to ${summary_path}\n")

  $report_path = "${report_prefix}.report.${report_timestamp}${extra_label}.yaml"
  file::write($report_path, $repos.to_yaml)
  out::message("\nWrote repos data ${report_path}\n")
}
