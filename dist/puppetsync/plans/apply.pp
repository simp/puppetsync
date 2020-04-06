
plan puppetsync::apply(
  TargetSpec $targets = get_targets('localhost'),
){
  # A directory out local user should have write access to
  $project_dir = system::env('PWD')

  $named_local_target = Target.new( 'name' => 'named_local_target' )
  $named_local_target.add_to_group( 'repo_targets' )

  $both_targets = [$targets[0], $named_local_target]

  $both_targets.each |$target| {
    out::message( "==== target ${target} apply:" )
    apply(
      $target,
      '_description' => "Test puppet apply",
      '_noop' => false,
      _catch_errors => false
    ){
      warning( "------------------ TARGET: ${target.name}")
      file{ "$project_dir/foo.${target.name}.txt": content => $target.vars['content'] }
    }
  }
}
