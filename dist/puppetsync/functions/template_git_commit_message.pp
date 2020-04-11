function puppetsync::template_git_commit_message(
  Target $target,
  Hash   $puppetsync_config,
){
  $subtask_key       = $target.vars.dig('jira_subtask_key').lest || {
    warning("WARNING: ${target.name} missing expected var ['jira_subtask_key'] (using '')")
    ''
  }
  $parent_issue      = $puppetsync_config.dig('jira','parent_issue').lest || {
    warning("WARNING: ${target.name} missing expected var ['jira']['parent_issue'] (using '')")
    ''
  }
  $commmit_template  = $puppetsync_config.dig('git','commit_message').lest || {
    fail("ERROR: ${target.name} missing required var ['git']['commit_message']")
  }
  $component_name    = $target.vars['mod_data']['repo_name'].lest || {
    fail("ERROR: ${target.name} missing required var ['mod_data']['repo_name']")
  }

  $puppetsync_config['git']['commit_message'].regsubst( '%JIRA_SUBTASK%', $subtask_key, 'G'
    ).regsubst( '%JIRA_PARENT_ISSUE%', $parent_issue, 'G'
    ).regsubst( '%COMPONENT%', $component_name, 'G')
}
