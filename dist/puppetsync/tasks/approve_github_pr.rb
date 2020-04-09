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
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each{ |path| $LOAD_PATH << path } # for octokit

    require_relative '../../puppetsync/files/ensure_github_pr_forker.rb'

    forker = GitHubPRForker.new( nil, kwargs[:github_authtoken] )
    pr = forker.existing_pr(kwargs[:"target_repo"], kwargs[:target_branch], kwargs[:fork_user], kwargs[:fork_branch] )
    approval = forker.approve_pr(pr, kwargs[:approval_message] || ':+1: :ghost:')
    {
      approval_id:    approval.id,
      state:          approval.state,
      approval_url:   approval.html_url,
      pr_number:      pr.number,
      pr_url:         pr.html_url,
      target_repo:    pr.base.repo.full_name,
      target_branch:  pr.base.ref,
      fork_repo:      pr.head.repo.full_name,
      fork_branch:    pr.head.ref,
    }
  end
end

MyTask.run if __FILE__ == $0
