#!/opt/puppetlabs/bolt/bin/ruby
# ------------------------------------------------------------------------------
# Usage:
#
#   bolt task run puppetsync::ensure_github_fork \
#      -t localhost \
#      github_repo=simp/pupmod-simp-acpid
#      github_user="$GITHUB_USER" \
#      github_authtoken="$GITHUB_API_TOKEN" \
#      extra_gem_paths='["/path/to/puppetsync/gems"]'
#
require_relative '../../ruby_task_helper/files/task_helper.rb'

class MyTask < TaskHelper
  def task(name: nil, **kwargs)
    # Ensure that extra gem paths are loaded (to find octokit)
    kwargs[:extra_gem_paths].each{ |gempath| Dir["#{gempath}/gems/*/lib"].each{ |path| $LOAD_PATH << path }}
    require_relative '../../puppetsync/files/ensure_github_pr_forker.rb'
    forker = GitHubPRForker.new( kwargs[:github_user], kwargs[:github_authtoken] )
    repo_fork = forker.ensure_fork( kwargs[:github_repo] )
    {
      user_fork: repo_fork.full_name,
      owner: repo_fork.owner[:login],
      ssh_url: repo_fork[:ssh_url],
      clone_url: repo_fork[:clone_url],
      upstream_repo: kwargs[:github_repo]
    }
  end
end

MyTask.run if __FILE__ == $0
