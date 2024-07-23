# @summary Idempotently ensures that a Jira subtask exists for each repo
#
# Idempotently ensures that a Jira subtask exists for each repo
#
# @param repos
#   The repo targets to process
#
# @param puppetsync_config
#   Hash of setting for this pecific update session
#
# @param extra_gem_path
#   Path to a gem path with extra gems the bolt interpreter will to run
#   some of the Ruby tasks.
#   (Default: `${PWD}/.plan.gems`)
#
# @param jira_username
#    Jira API username (probably an email address)
#    (Default: Environment variable `$JIRA_USER`)
#
# @param jira_token
#   Jira API token
#   (Default: Environment variable `$JIRA_API_TOKEN`)
#
# @return [Optional[Variant[Result, ApplyResult]]]
function puppetsync::ensure_jira_subtask_for_each_repo(
  TargetSpec           $repos,
  Hash                 $puppetsync_config,
  String[1]            $jira_username  = system::env('JIRA_USER'),
  Sensitive[String[1]] $jira_token     = Sensitive(system::env('JIRA_API_TOKEN')),
  Stdlib::Absolutepath $extra_gem_path = "#{system::env('PWD')}/.plan.gems"
) >> Optional[Variant[Result, ApplyResult]] {
  $repos.map |$target| {
    assert_type( Hash, $puppetsync_config['jira'])
    $set_assignee = $puppetsync_config['jira']['subtask_assignee'] ? {
      true    => $puppetsync_config['jira']['subtask_assignee'],
      default => undef,
    }
    # TODO: This doesn't work and isn't important to fix: always set to undef?
    $description = $puppetsync_config['jira']['subtask_description'].empty ? {
      false   => $puppetsync_config['jira']['subtask_description'],
      default => undef,
    }
    $story_points = String($puppetsync_config['jira']['subtask_story_points']).empty ? {
      false   => $puppetsync_config['jira']['subtask_story_points'],
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
        'subtask_assignee'     => $set_assignee,
        'jira_site'            => $puppetsync_config['jira']['jira_site'],
        'jira_username'        => $jira_username,
        'jira_token'           => $jira_token.unwrap,
        'extra_gem_path'      => $extra_gem_path,
        '_catch_errors'        => true,
      }
    )

    if $results.ok {
      $subtask_key = $results.first.value['subtask_key']
      $target.set_var( 'jira_subtask_key', $subtask_key )
      out::message("Jira subtask for '${target.name}': ${subtask_key}")
    } else {
      warning("WARNING: Running puppetsync::ensure_jira_subtask FAILED on ${target.name}")
      warning("repos.count=${repos.count}")
    }
    $results.first
  }
}
