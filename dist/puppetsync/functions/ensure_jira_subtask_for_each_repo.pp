function puppetsync::ensure_jira_subtask_for_each_repo(
  TargetSpec           $repos,
  Hash                 $puppetsync_config,
  String[1]            $jira_username          = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token             = Sensitive(system::env('JIRA_API_TOKEN')),
  Array[Stdlib::Absolutepath] $extra_gem_paths = ["${pwd}/gems"]
) {
  $repos.each |$target| {
    assert_type( Hash, $puppetsync_config['jira'])
    $assignee =  $puppetsync_config['jira']['assignee'].empty ? {
      false   =>  $puppetsync_config['jira']['assignee'],
      default => undef,
    }

    $results = run_task(
      'puppetsync::ensure_jira_subtask',
      $target,
      "Ensure a Jira subtask under ${puppetsync_config['jira']['parent_issue']} exists",
      {
        'component_name' => $target.vars['mod_data']['repo_name'],
        'parent_issue'   => $puppetsync_config['jira']['parent_issue'],
        'project'        => $puppetsync_config['jira']['project'],
        'subtask_title'        => $puppetsync_config['jira']['subtask_title'],
        'subtask_description'  => $puppetsync_config['jira']['subtask_description'],
        'subtask_story_points' => $puppetsync_config['jira']['subtask_story_points'],
        'subtask_assignee'     => $assignee,
        'jira_site'            => $puppetsync_config['jira']['jira_site'],
        'jira_username'        => $jira_username,
        'jira_token'           => $jira_token.unwrap,
        'extra_gem_paths'      => $extra_gem_paths,
        '_catch_errors'        => true,
      }
    )

    unless $results.ok { fail("Running puppetsync::ensure_jira_subtask failed on ${target.name}") }

    $subtask_key = $results.first.value['subtask_key']
    $target.set_var( 'jira_subtask_key', $subtask_key )
    out::message("Jira subtask for '${target.name}': ${subtask_key}")
  }
}
