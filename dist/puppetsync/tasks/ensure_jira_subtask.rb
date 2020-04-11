#!/opt/puppetlabs/bolt/bin/ruby

require_relative '../../puppetsync/files/ensure_jira_subtask.rb'
require_relative '../../ruby_task_helper/files/task_helper.rb'

class MyTask < TaskHelper
  def task(name: nil, **kwargs)
    # Ensure that extra gem paths are loaded (to find jira-ruby)
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each{ |path| $LOAD_PATH << path }
    api = JiraHelper.new(
      kwargs[:jira_username],
      kwargs[:jira_token],
      kwargs[:jira_site],
    )
    # TODO: optional labels []
    subtask_key = api.ensure_subtask(
      kwargs[:project] || 'SIMP',
      kwargs[:parent_issue],
      kwargs[:component_name],
      kwargs.select{|k,v| k.to_s =~ /^subtask_/}
    )
    { subtask_key: subtask_key, parent_issue: kwargs[:parent_issue] }
  end
end


MyTask.run if __FILE__ == $0
