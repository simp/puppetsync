#!/opt/puppetlabs/bolt/bin/ruby
# ------------------------------------------------------------------------------
# Usage:
#
#   bolt task run puppetsync::set_github_pr_state \
#      -t localhost \
#      target_repo=simp/pupmod-simp-acpid \
#      target_branch=master \
#      fork_user=someuser \
#      fork_branch=puppetsync/YYYYMMDD-session \
#      state=draft \
#      github_authtoken="$GITHUB_API_TOKEN" \
#      extra_gem_path='/path/to/puppetsync/.plan.gems'
#
require_relative '../../ruby_task_helper/files/task_helper.rb'

class MyTask < TaskHelper
  def task(name: nil, **kwargs)
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each { |path| $LOAD_PATH << path } # for octokit

    require_relative '../../puppetsync/files/github_pr_forker.rb'

    forker = GitHubPRForker.new(kwargs[:github_authtoken])
    pr = forker.existing_pr(kwargs[:target_repo], kwargs[:target_branch], kwargs[:fork_user], kwargs[:fork_branch])
    raise "No open PR found for #{kwargs[:fork_user]}:#{kwargs[:fork_branch]} -> #{kwargs[:target_repo]}:#{kwargs[:target_branch]}" unless pr

    draft = (kwargs[:state].to_s == 'draft')
    changed = forker.set_pr_draft_state(pr, draft)
    {
      changed:       changed,
      draft:         draft,
      pr_number:     pr.number,
      pr_url:        pr.html_url,
      target_repo:   pr.base.repo.full_name,
      target_branch: pr.base.ref,
      fork_branch:   pr.head.ref,
    }
  end
end

MyTask.run if $PROGRAM_NAME == __FILE__
