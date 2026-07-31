# Test-support plan: a target that fails a stage must be held back from
# later stages while other targets proceed
plan puppetsync_test::stage_holdback() {
  $good = Target.new('name' => 'good-repo')
  $bad = Target.new('name' => 'bad-repo')
  [$good, $bad].each |$t| { $t.set_var('puppetsync_stage_results', {}) }

  [$good, $bad].puppetsync::pipeline_stage(
    'first_stage',
    { 'stages' => ['first_stage', 'second_stage'] }
  ) |$ok_repos, $stage_name| {
    run_command('stage-one', $ok_repos, { '_catch_errors' => true })
  }

  $survivors = [$good, $bad].puppetsync::pipeline_stage(
    'second_stage',
    { 'stages' => ['first_stage', 'second_stage'] }
  ) |$ok_repos, $stage_name| {
    run_command('stage-two', $ok_repos, { '_catch_errors' => true })
  }

  return($survivors.map |$t| { $t.name })
}
