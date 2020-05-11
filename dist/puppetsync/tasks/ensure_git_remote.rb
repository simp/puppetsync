#!/opt/puppetlabs/bolt/bin/ruby
# ------------------------------------------------------------------------------
# Usage:
#
#   bolt task run puppetsync::ensure_git_remote -t localhost \
#     repo_path=$PWD/_repos/aide \
#     remote_url=git@github.com:op-ct/pupmod-simp-aide.git \
#     remote_name=test_remote
#
require_relative '../../ruby_task_helper/files/task_helper.rb'
require_relative '../../puppetsync/files/git_repo_remote_tasks.rb'

class MyTask < TaskHelper
  def task(name: nil, **kwargs)
    helper = GitRepoRemoteTasks.new(kwargs[:repo_path], kwargs[:remote_url], kwargs[:remote_name])
    helper.ensure_remote_exists
    {
      repo_path: kwargs[:repo_path],
      remote_url: kwargs[:remote_url],
      remote_name: kwargs[:remote_name],
    }
  end
end

MyTask.run if $PROGRAM_NAME == __FILE__
