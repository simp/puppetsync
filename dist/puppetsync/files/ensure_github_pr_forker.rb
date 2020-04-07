require 'octokit'

class GitHubPRForker
  attr_reader :created_pr, :created_fork

  def initialize(github_user=ENV['GITHUB_USER'], github_authtoken=ENV['GITHUB_API_TOKEN'])
    @client = Octokit::Client.new(:access_token => github_authtoken)
    @user = github_user
    @created_pr = false
    @created_fork = false
  end

  # return the user's fork of the upstream repo, or nil if there isn't one
  def forked_user_repo(upstream_reponame)
    upstream_repo =  @client.repo upstream_reponame
    forks = @client.forks(upstream_repo.full_name)
    forks = forks.select{|x| x[:owner][:login] == @user }
    forks.empty? ? nil : forks.first
  end

  def ensure_fork(upstream_reponame, opts={})
    repo_fork = forked_user_repo(upstream_reponame)
    return repo_fork if repo_fork

    warn( "=== Forking #{upstream_reponame}" )
    created_fork = @client.fork(upstream_reponame)
    @created_fork = true
    created_fork
    # TODO: should we also block until the new repo is ready?  How will we know?
  end

  # return array of prs that already exist for this chang
  def existing_prs(upstream_reponame, opts)
    repo_fork = forked_user_repo(upstream_reponame)
    @client.pull_requests( upstream_reponame ).select do |pr|
      pr.user.login == @user && \
      pr.head.repo.full_name == repo_fork.full_name && \
      pr.head.ref == opts[:fork_branch] && \
      pr.base.ref == opts[:target_branch]
      # TODO: should we test for merged PRs, too?
    end
  end

  def create_pr(upstream_reponame, opts)
    repo_fork = forked_user_repo(upstream_reponame)
    unless repo_fork
      fail("ERROR: no fork of '#{upstream_reponame}' found for user #{@user}")
    end
    commit_msg_lines = opts[:commit_message].split("\n")
    title = commit_msg_lines.shift
    body  = commit_msg_lines.join("\n").strip
    head  = "#{repo_fork.owner.login}:#{opts[:fork_branch]}"
    warn( "=== Creating PR #{head} -> #{upstream_reponame}:#{opts[:target_branch]}" )
    pr =  @client.create_pull_request( upstream_reponame, opts[:target_branch], head, title, body )
    @created_pr = true
    pr
  end

  def ensure_pr(upstream_reponame, opts)
    existing_prs_for_this_change = existing_prs(upstream_reponame, opts)
    if existing_prs_for_this_change.empty?
      return(create_pr(upstream_reponame, opts))
    end

    if existing_prs_for_this_change.size > 1
      raise 'More than one PR already exists for this change'
    end
    pr = existing_prs_for_this_change.first
    warn( "--- PR ##{pr.number} already exists for: #{opts[:fork_branch]} -> #{upstream_reponame}:#{opts[:target_branch]}" )
    return pr
  end
end

if __FILE__ == $0

  forker = GitHubPRForker.new( ENV['GITHUB_USER'], ENV['GITHUB_API_TOKEN'])
  fail( 'set ENV var UPSTREAM_REPO (ex: \'UPSTREAM_REPO=simp/pupmod-simp-aide\')' ) unless ENV['UPSTREAM_REPO']
  upstream_reponame = ENV['UPSTREAM_REPO'] || 'simp/pupmod-simp-aide'
  repo_fork = forker.ensure_fork(upstream_reponame)
  opts = {
    target_branch: 'master',
    fork_branch:   'SIMP-7035',
    commit_message: (<<~COMMIT_MESSAGE
      (SIMP-7035) Update to new Travis CI pipeline

      This patch updates the Travis Pipeline to a static, standardized format
      that uses project variables for secrets. It includes an optional
      diagnostic mode to test the project's variables against their respective
      deployment APIs (GitHub and Puppet Forge).

      SIMP-7035 #comment Update to latest pipeline in pupmod-simp-aide
      SIMP-7624 #close
      COMMIT_MESSAGE
    )
  }
  repo_pr = forker.ensure_pr(upstream_reponame, opts )

require 'pry'; binding.pry
end
