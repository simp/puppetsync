require 'octokit'

class GitHubPRForker
  attr_reader :created_pr, :created_fork

  def initialize(github_authtoken=ENV['GITHUB_API_TOKEN'])
    @client = Octokit::Client.new(:access_token => github_authtoken)
    @created_pr = false
    @created_fork = false
  end

  # return user's (defaults to @client.login) fork of the upstream repo, or nil if there isn't one
  def user_fork_of_repo(upstream_reponame, fork_user=@client.login)
    upstream_repo =  @client.repo upstream_reponame
    forks = @client.forks(upstream_repo.full_name)
    forks = forks.select{|x| x[:owner][:login] == fork_user }
    forks.empty? ? nil : forks.first
  end

  def ensure_fork(upstream_reponame, opts={})
    repo_fork = user_fork_of_repo(upstream_reponame)
    return repo_fork if repo_fork

    warn( "=== Forking #{upstream_reponame}" )
    created_fork = @client.fork(upstream_reponame)
    @created_fork = true
    created_fork
    # TODO: should we also block until the new repo is ready?  How will we know?
  end

  # return array of PRs that already exist for this change
  def existing_pr(upstream_reponame, target_branch, fork_user, fork_branch)
    repo_fork = user_fork_of_repo(upstream_reponame, fork_user)
    prs = @client.pull_requests( upstream_reponame ).select do |pr|
      pr.user.login == fork_user && \
      pr.head.repo.full_name == repo_fork.full_name && \
      pr.head.ref == fork_branch && \
      pr.base.ref == target_branch
      # TODO: should we test for merged PRs, too?   How?
    end
    return nil unless prs
    raise 'More than one PR already exists for this change' if prs.size > 1
    prs.first
  end

  def create_pr(upstream_reponame, target_branch, fork_branch, commit_message)
    repo_fork = user_fork_of_repo(upstream_reponame)
    unless repo_fork
      fail("ERROR: no fork of '#{upstream_reponame}' found for user #{@client.login}")
    end
    commit_msg_lines = commit_message.split("\n")
    title = commit_msg_lines.shift
    body  = commit_msg_lines.join("\n").strip
    head  = "#{repo_fork.owner.login}:#{fork_branch}"
    warn( "=== Creating PR #{head} -> #{upstream_reponame}:#{target_branch}" )
    pr =  @client.create_pull_request( upstream_reponame, target_branch, head, title, body )
    @created_pr = true
    pr
  end

  def update_pr(pr, commit_message)
    commit_msg_lines = commit_message.split("\n")
    title = commit_msg_lines.shift
    body  = commit_msg_lines.join("\n").strip
    head  = "#{pr.user.login}:#{pr.head.ref}"
    warn( "=== Updating PR #{head} -> #{pr.base.repo.full_name}:#{pr.base.ref}" )
    @client.update_pull_request( pr.base.repo.full_name, pr.number, {:title => title, :body => body} )
  end

  # Idempotently creates or updates a PR
  #
  # @return object of created/updated PR
  def ensure_pr(upstream_reponame, opts)
    fork_branch, target_branch, commit_message =  opts[:fork_branch], opts[:target_branch], opts[:commit_message]
    pr = existing_pr(upstream_reponame, target_branch, @client.login, fork_branch)
    return(create_pr(upstream_reponame, target_branch, fork_branch, commit_message)) unless pr
    warn( "--- PR ##{pr.number} already exists for: #{fork_branch} -> #{upstream_reponame}:#{target_branch}; updating" )
    update_pr(pr, commit_message)
  end

  # @return [Array] Approvals that already exist for this PR
  def pr_approvals(pr, approving_user=nil)
    reviews = @client.pull_request_reviews( pr.base.repo.full_name, pr.number )
    reviews.select do |r|
      r.state == 'APPROVED' && (approving_user ? (r.user.login == approving_user ) : true)
    end
  end

  # Should this be fancy and dismiss of our revious REQUEST_CHANGES comments?
  def approve_pr(pr, approval_message)
    raise 'No PR exists to approve' unless pr
    approval_tag = "<!-- #{pr.head.ref}:#{@client.login}:AUTOAPPROVER -->"
    tagged_approval_message = "#{approval_message||''}\n#{approval_tag}"
    my_approvals = pr_approvals(pr, @client.login)
    opts = { event: 'APPROVE', body: tagged_approval_message }
    if my_approvals.empty?
      warn("== Approving PR #{pr.html_url}")
      review = @client.create_pull_request_review( pr.base.repo.full_name, pr.number, opts )
    elsif old_review = my_approvals.select{|x| x.body =~ Regexp.new(approval_tag)}.last
      puts "== we have already left an approval with this software; updating"
      review = @client.update_pull_request_review(
        pr.base.repo.full_name, pr.number, old_review.id, "#{tagged_approval_message}\n<!-- updated by robot -->"
      )
    else
      warn("!! we have already approved PR ##{pr.number}, but not with this software")
      warn("== Approving PR #{pr.html_url}")
      review = @client.create_pull_request_review( pr.base.repo.full_name, pr.number, opts )
    end
    review
  end

  def merge_pr(pr)
    raise 'No PR exists to approve' unless pr
    raise "PR already approved: '#{pr.html_url}'" if @client.pull_merged?( pr.base.repo.full_name, pr.number)
    @client.merge_pull_request(
      pr.base.repo.full_name,
      pr.number,
      '',
      {
        :merge_method => 'squash',
      }
    )
  end

end

if __FILE__ == $0

  forker = GitHubPRForker.new( ENV['GITHUB_API_TOKEN'])
  fail( 'set ENV var UPSTREAM_REPO (ex: \'UPSTREAM_REPO=simp/pupmod-simp-at\')' ) unless ENV['UPSTREAM_REPO']
  upstream_reponame = ENV['UPSTREAM_REPO'] || 'simp/pupmod-simp-at'
  ###repo_fork = forker.ensure_fork(upstream_reponame)

  ### PR:
  ####opts = {
  ####  target_branch: 'master',
  ####  fork_branch:   'SIMP-7035',
  ####  commit_message: (<<~COMMIT_MESSAGE
  ####    (SIMP-7035) Update to new Travis CI pipeline

  ####    This patch updates the Travis Pipeline to a static, standardized format
  ####    that uses project variables for secrets. It includes an optional
  ####    diagnostic mode to test the project's variables against their respective
  ####    deployment APIs (GitHub and Puppet Forge).

  ####    SIMP-7035 #comment Update to latest pipeline in pupmod-simp-at
  ####    SIMP-7617 #close
  ####    COMMIT_MESSAGE
  ####  )
  ####}

  ###opts = {
  ###  target_branch: 'master',
  ###  fork_branch:   'SIMP-7035',
  ###  commit_message: ( <<~COMMIT_MESSAGE
  ###    (SIMP-7035) Update to new Travis CI pipeline

  ###    This patch updates the Travis Pipeline to a static, standardized format
  ###    that uses project variables for secrets. It includes an optional
  ###    diagnostic mode to test the project\'s variables against their respective
  ###    deployment APIs (GitHub and Puppet Forge).

  ###    SIMP-7035 #comment Update to latest pipeline in pupmod-simp-at
  ###    SIMP-7617 #close
  ###    COMMIT_MESSAGE
  ###  ),
  ###  approval_message: "Update of static, non-code file approved in https://github.com/simp/pupmod-simp-aide/pull/59",
  ###  merge_message: nil,
  ###}
  opts = {
    fork_user: 'op-ct',
    target_branch: 'master',
    fork_branch:   'SIMP-7035',
  }
  pr = forker.existing_pr(upstream_reponame, opts[:target_branch], opts[:fork_user], opts[:fork_branch] )
  ###repo_pr = forker.approve_pr(pr, opts[:approval_message] || ':+1: :ghost:')
  result = forker.merge_pr(pr)

require 'pry'; binding.pry
end
