require 'octokit'

class GitHubPRForker
  def initialize(github_user=ENV['GITHUB_USER'], github_authtoken=ENV['GITHUB_API_TOKEN'])
    @client = Octokit::Client.new(:access_token => github_authtoken)
    @user = github_user
  end

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
    @client.fork(upstream_reponame)
  end

  # TODO: implement PR logic
  def ensure_pr(upstream_reponame, opts)
    repo_fork = forked_user_repo(upstream_repo)
    upstream_repo =  @client.repo upstream_reponame
require 'pry'; binding.pry
  end
end

if __FILE__ == $0
  forker = GitHubPRForker.new( ENV['GITHUB_USER'], ENV['GITHUB_API_TOKEN'])
  fail( 'set ENV var UPSTREAM_REPO (ex: \'UPSTREAM_REPO=simp/pupmod-simp-acpid\')' ) unless ENV['UPSTREAM_REPO']
  repo_fork = forker.ensure_fork(ENV['UPSTREAM_REPO'] || 'simp/pupmod-simp-acpid')
require 'pry'; binding.pry
end
