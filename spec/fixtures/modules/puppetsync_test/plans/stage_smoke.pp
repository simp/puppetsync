# Test-support plan: exercises puppetsync::pipeline_stage gating
plan puppetsync_test::stage_smoke() {
  $changed = Target.new('name' => 'changed-repo')
  $unchanged = Target.new('name' => 'unchanged-repo')
  [$changed, $unchanged].each |$t| { $t.set_var('puppetsync_stage_results', {}) }
  $unchanged.set_var('puppetsync_unchanged', true)

  $ran = [$changed, $unchanged].puppetsync::pipeline_stage(
    'gated_stage',
    { 'stages' => ['gated_stage'], 'skip_unchanged_targets' => true }
  ) |$ok_repos, $stage_name| {
    run_command('true', $ok_repos)
  }

  $skipped = [$changed, $unchanged].puppetsync::pipeline_stage(
    'not_in_stage_list',
    { 'stages' => ['gated_stage'] }
  ) |$ok_repos, $stage_name| {
    run_command('true', $ok_repos)
  }

  return({ 'ran' => $ran.map |$t| { $t.name }, 'skipped_stage_result' => $skipped })
}
