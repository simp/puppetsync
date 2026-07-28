#!/opt/puppetlabs/bolt/bin/ruby

require 'json'
require 'open3'
require 'tempfile'

def git(*args)
  out, status = Open3.capture2e('git', *args)
  raise("ERROR: 'git #{args.join(' ')}' failed in #{Dir.pwd}:\n#{out}") unless status.success?
  out
end

def git_commit(repo_path, commit_message)
  Dir.chdir repo_path

  warn "NOTICE: Running 'git add -A' in #{repo_path}"
  git('add', '-A')

  # `git diff --cached --quiet` exits 0 when nothing is staged
  if system('git', 'diff', '--cached', '--quiet')
    warn "== #{File.basename(repo_path)} : nothing to commit in #{repo_path}"
    return { 'changed' => false }
  end

  # Amend instead of piling up commits when re-running the same session
  # (compare with trailing whitespace stripped: `git log --pretty=%B` output
  # carries trailing newlines that the commit_message parameter may not have)
  amend = git('log', '-1', '--pretty=%B').rstrip == commit_message.rstrip

  Tempfile.create('commit_msg_file') do |commit_msg_file|
    commit_msg_file.write(commit_message)
    commit_msg_file.flush

    args = ['commit', '-F', commit_msg_file.path]
    args << '--amend' if amend
    warn "NOTICE: Running 'git #{args.join(' ')}' in #{repo_path}"
    git(*args)
  end

  warn "== #{File.basename(repo_path)} : committed changes in #{repo_path}"
  { 'changed' => true, 'amended' => amend }
end

stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

raise('No repo path given') unless params['repo_path']
raise('No commit_message given') unless params['commit_message']
puts JSON.generate(git_commit(params['repo_path'], params['commit_message']))
