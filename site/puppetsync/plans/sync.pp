plan puppetsync::sync(
  #  TargetSpec
) {
  $t1 = Target.new(
    'name' => 'fred',
    'config' => {
      'transport' => 'local'
      }
  )
  $t2 = Target.new(
    'name' => 'wilma',
    'config' => {
      'transport' => 'local'
      }
  )

  $t1.add_to_group('repo_targets')
  $t2.add_to_group('repo_targets')
  $repos = get_targets('repo_targets')
  out::message( "Targets: ${targets.size}" )
  $repos.each |$target| {
    out::message( "Target: ${target.name}" )
  }
  return run_command('/usr/bin/date', 'repo_targets' )
}
