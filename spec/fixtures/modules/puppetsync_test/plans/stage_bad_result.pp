# Test-support plan: a stage block returning something other than Bolt
# results must fail the plan (see #52/#64)
plan puppetsync_test::stage_bad_result() {
  $t = Target.new('name' => 'some-repo')
  $t.set_var('puppetsync_stage_results', {})

  [$t].puppetsync::pipeline_stage(
    'bad_stage',
    { 'stages' => ['bad_stage'] }
  ) |$ok_repos, $stage_name| {
    'this is not a Bolt::Result'
  }
}
