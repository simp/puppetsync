#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'
require 'open3'

def git(*args, chdir: nil)
  cmd = ['git'] + args
  opts = chdir ? { chdir: chdir } : {}
  out, status = Open3.capture2e(*cmd, **opts)
  raise("ERROR: '#{cmd.join(' ')}' failed#{chdir ? " in #{chdir}" : ''}:\n#{out}") unless status.success?
  out
end

def existing_clone_matches?(repo_path, git_url)
  return false unless File.directory?(File.join(repo_path, '.git'))

  out, status = Open3.capture2e('git', 'remote', 'get-url', 'origin', chdir: repo_path)
  status.success? && out.strip == git_url
end

# Bring an existing clone to the same state a fresh clone would have:
# base branch at origin's tip, clean working tree, no leftover local branches
def update_clone(repo_path, branch)
  git('fetch', '--prune', 'origin', chdir: repo_path)
  git('checkout', '-B', branch, "origin/#{branch}", chdir: repo_path)
  # checkout -B carries over dirty tracked files; reset --hard discards them
  git('reset', '--hard', "origin/#{branch}", chdir: repo_path)
  git('clean', '-fdx', chdir: repo_path)

  local_branches = git('for-each-ref', '--format=%(refname:short)', 'refs/heads', chdir: repo_path).split("\n")
  (local_branches - [branch]).each { |stale| git('branch', '-D', stale, chdir: repo_path) }
end

def clone(git_url, repo_path, branch)
  FileUtils.mkdir_p(File.dirname(repo_path))
  git('clone', git_url, repo_path, '-b', branch)
end

def ensure_git_clone(git_url, repo_path, branch, clear)
  if existing_clone_matches?(repo_path, git_url)
    warn "== #{File.basename(repo_path)} : updating existing clone in #{repo_path}"
    update_clone(repo_path, branch)
    { 'method' => 'updated' }
  elsif File.exist?(repo_path)
    unless clear
      raise("ERROR: '#{repo_path}' exists but is not a clone of '#{git_url}' " \
            '(and clear_before_clone is false, so it will not be replaced)')
    end
    warn "== #{File.basename(repo_path)} : replacing '#{repo_path}' (not a clone of #{git_url})"
    FileUtils.rm_rf(repo_path)
    clone(git_url, repo_path, branch)
    { 'method' => 'recloned' }
  else
    warn "== #{File.basename(repo_path)} : cloning #{git_url} into #{repo_path}"
    clone(git_url, repo_path, branch)
    { 'method' => 'cloned' }
  end
end

stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

raise('No git_url given') unless params['git_url']
raise('No repo_path given') unless params['repo_path']
raise('No branch given') unless params['branch']
clear = params.fetch('clear', true)

puts JSON.generate(ensure_git_clone(params['git_url'], params['repo_path'], params['branch'], clear))
