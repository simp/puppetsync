#!/opt/puppetlabs/bolt/bin/ruby
# ------------------------------------------------------------------------------
# Usage:
#
#   bolt task run puppetsync::ensure_github_fork \
#      -t localhost \
#      github_repo=simp/pupmod-simp-acpid
#      github_authtoken="$GITHUB_API_TOKEN" \
#      extra_gem_path='/path/to/puppetsync/.plan.gems'
#
require_relative '../../ruby_task_helper/files/task_helper.rb'

# Bolt task class
class MyTask < TaskHelper
  def task(name: nil, **kwargs) # rubocop:disable Lint/UnusedMethodArgument
    # Ensure that extra gem paths are loaded (to find octokit)
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each { |path| $LOAD_PATH << path }
    require_relative '../../puppetsync/files/github_pr_forker.rb'
    forker = GitHubPRForker.new(kwargs[:github_authtoken])
    repo_fork = forker.ensure_fork(kwargs[:github_repo])
    {
      user_fork: repo_fork.full_name,
      owner: repo_fork.owner[:login],
      ssh_url: repo_fork[:ssh_url],
      clone_url: repo_fork[:clone_url],
      upstream_repo: kwargs[:github_repo],
    }
  end
end

MyTask.run if $PROGRAM_NAME == __FILE__
