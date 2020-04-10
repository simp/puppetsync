function puppetsync::template_git_commit_message(
  Target $target,
  Hash   $puppetsync_config,
){
  $subtask_key       = $target.vars['jira_subtask_key']
  $parent_issue      = $puppetsync_config['jira']['parent_issue']
  $commmit_template  = $puppetsync_config['git']['commit_message']
  $component_name    = $target.vars['mod_data']['repo_name']
  $commmit_template.regsubst('%JIRA_SUBTASK%', $subtask_key, 'G' ).regsubst('%JIRA_PARENT_ISSUE%', $parent_issue, 'G').regsubst('%COMPONENT%', $component_name, 'G')
}
