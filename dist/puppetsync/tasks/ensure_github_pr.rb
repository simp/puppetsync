#!/opt/puppetlabs/bolt/bin/ruby
# ------------------------------------------------------------------------------
# Usage:
#
#   bolt task run puppetsync::ensure_github_fork \
#      -t localhost \
#      github_repo=simp/pupmod-simp-acpid
#      github_user="$GITHUB_USER" \
#      github_authtoken="$GITHUB_API_TOKEN" \
#      extra_gem_path='/path/to/puppetsync/.gems'
#
require_relative '../../ruby_task_helper/files/task_helper.rb'

class MyTask < TaskHelper
  def task(name: nil, **kwargs)
    # Ensure that extra gem paths are loaded (to find octokit)
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each{ |path| $LOAD_PATH << path }
    require_relative '../../puppetsync/files/ensure_github_pr_forker.rb'
    forker = GitHubPRForker.new( kwargs[:github_user], kwargs[:github_authtoken] )

    opts = {
      target_branch:  kwargs[:target_branch],
      fork_branch:    kwargs[:fork_branch],
      commit_message: kwargs[:commit_message],
    }
    repo_pr = forker.ensure_pr(kwargs[:target_repo], opts )
    {
      pr_created:       forker.created_pr,
      pr_number:        repo_pr.number,
      pr_url:           repo_pr.html_url,
      upstream_repo:    repo_pr.base.repo.full_name,
      upstream_branch:  repo_pr.base.ref,
      user_repo:        repo_pr.head.repo.full_name,
      user_branch:      repo_pr.head.ref,
    }
  end
end

MyTask.run if __FILE__ == $0
