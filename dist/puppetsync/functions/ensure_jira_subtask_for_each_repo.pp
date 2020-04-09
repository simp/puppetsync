function puppetsync::ensure_jira_subtask_for_each_repo(
  TargetSpec           $repos,
  Hash                 $puppetsync_config,
  String[1]            $jira_username          = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token             = Sensitive(system::env('JIRA_API_TOKEN')),
  Array[Stdlib::Absolutepath] $extra_gem_paths = ["${pwd}/gems"]
) {
  $repos.each |$target| {
    assert_type( Hash, $puppetsync_config['jira'])
    $assignee = $puppetsync_config['jira']['subtask_assignee'].empty ? {
      false   =>  $puppetsync_config['jira']['subtask_assignee'],
      default => undef,
    }
    $description = $puppetsync_config['jira']['subtask_description'].empty ? {
      false   =>  $puppetsync_config['jira']['subtask_description'],
      default => undef,
    }
    $story_points = "${puppetsync_config['jira']['subtask_story_points']}".empty ? {
      false   =>  $puppetsync_config['jira']['subtask_story_points'],
      default => undef,
    }

    $results = run_task(
      'puppetsync::ensure_jira_subtask',
      $target,
      "Ensure a Jira subtask under ${puppetsync_config['jira']['parent_issue']} exists",
      {
        'component_name'       => $target.vars['mod_data']['repo_name'],
        'parent_issue'         => $puppetsync_config['jira']['parent_issue'],
        'project'              => $puppetsync_config['jira']['project'],
        'subtask_title'        => $puppetsync_config['jira']['subtask_title'],
        'subtask_description'  => $description,
        'subtask_story_points' => $story_points,
        'subtask_assignee'     => $assignee,
        'jira_site'            => $puppetsync_config['jira']['jira_site'],
        'jira_username'        => "$jira_username",
        'jira_token'           => $jira_token.unwrap,
        'extra_gem_paths'      => $extra_gem_paths,
        '_catch_errors'        => true,
      }
    )

    $stage_result = {
      'ok'   => $results.first.ok,
      'data' => $results.first.to_data,
    }
    $merge_results =  $target.vars['puppetsync_stage_results'].merge(
      Hash({ 'ensure_jira_subtask' => Hash($stage_result) })
    )
    $target.set_var( 'puppetsync_stage_results', Hash($merge_results) )

    if $results.ok {
      $subtask_key = $results.first.value['subtask_key']
      $target.set_var( 'jira_subtask_key', $subtask_key )
      out::message("Jira subtask for '${target.name}': ${subtask_key}")
    } else {
      warning("WARNING: Running puppetsync::ensure_jira_subtask FAILED on ${target.name}")
      warning("repos.count=${repos.count}")
    }
  }
}
