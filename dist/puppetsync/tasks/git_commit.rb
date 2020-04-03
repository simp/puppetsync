#!/opt/puppetlabs/bolt/bin/ruby

require 'json'
require 'tempfile'

def git_commit(repo_path, commit_message)

  commit_msg_file = Tempfile.new('commit_msg_file')
  begin
    commit_msg_file.write(commit_message)
    commit_msg_file.close

    Dir.chdir repo_path
    warn "NOTICE: Running 'git add  -A' in #{repo_path}"
    pid = spawn 'git','add','-A'
    Process.wait pid

    current_commit = `git log -1 --pretty=%B`.chomp
    if current_commit == commit_message
      warn "NOTICE: Running 'git commit -F #{commit_msg_file.path} --amend' in #{repo_path}"
      pid = spawn 'git', 'commit', '-F', commit_msg_file.path, '--amend'
      Process.wait pid
    else
      warn "NOTICE: Running 'git commit -F #{commit_msg_file.path}' in #{repo_path}"
      pid = spawn 'git', 'commit', '-F', commit_msg_file.path
      Process.wait pid
    end
    if $?.success?
      puts "== #{File.basename(repo_path)} : committed changes in #{repo_path}"
    end
  ensure
    commit_msg_file.close
    commit_msg_file.unlink
  end
end

stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

fail("No repo path given") unless params['repo_path']
fail("No commit_message given") unless params['commit_message']
git_commit(params['repo_path'], params['commit_message'])

