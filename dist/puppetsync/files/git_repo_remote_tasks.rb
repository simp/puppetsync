require 'English'

# variables
class GitRepoRemoteTasks
  def initialize(repo_path, remote_url, remote_name = 'user_forked_repo')
    @repo_path   = repo_path
    @remote_url  = remote_url
    @remote_name = remote_name
  end

  def ensure_remote_exists
    Dir.chdir @repo_path do |dir|
      current_remote_url = `git config --get remote.#{@remote_name}.url`.chomp
      if current_remote_url.empty? || current_remote_url != @remote_url
        pid = spawn 'git', 'remote', 'rm', @remote_name
        Process.wait pid

        pid = spawn 'git', 'remote', 'add', @remote_name, @remote_url
        Process.wait pid

        raise "ERROR (#{File.basename(dir)}): Failed to set remote '#{@remote_name}' to '#{@remote_url}' in #{dir}" unless $CHILD_STATUS.success?
        puts "== #{File.basename(dir)} : set remote '#{@remote_name}' to '#{@remote_url}' in #{dir}"

      end
    end
  end

  def push_to_github_over_https(github_token)
    raise "Remote URL '#{@remote_url}` must be https!" unless %r{^https}i.match?(@remote_url)
    require 'pry'
    binding.pry # rubocop:disable Lint/Debugger
    # FIXME: no such thing as shl
    # shl ['git', 'push', remote_name, git_ref, '-f']
  end
end

if $PROGRAM_NAME == __FILE__
  require 'pry'
  repo_path = ARGV[0]
  ref = ARGV[0] || 'SIMP-7035' # rubocop:disable Lint/UselessAssignment
  remote_url = ARGV[1] || 'https://github.com/op-ct/pupmod-simp-aide'

  helper = GitRepoRemoteTasks.new(repo_path, remote_url)
  helper.ensure_remote_exists

  # TODO: Push to GitHub logic

end
