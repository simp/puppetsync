require 'spec_helper'

describe 'task: git_commit' do
  def git(*args)
    out, status = Open3.capture2e('git', '-C', @repo, *args)
    raise "git #{args.join(' ')} failed:\n#{out}" unless status.success?
    out
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @repo = dir
      git('init', '-b', 'main')
      git('config', 'user.email', 'ci@example.com')
      git('config', 'user.name', 'CI')
      File.write(File.join(@repo, 'README.md'), "hello\n")
      git('add', '-A')
      git('commit', '-m', 'initial')
      example.run
    end
  end

  it 'commits pending changes with the given message' do
    File.write(File.join(@repo, 'new_file'), "content\n")

    _stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => 'add new file')

    expect(status).to be_success, stderr
    expect(git('log', '-1', '--pretty=%s').strip).to eq('add new file')
    expect(git('status', '--porcelain')).to be_empty
  end

  it 'amends the HEAD commit when the message matches' do
    # Production commit messages are multi-line templates ending in a newline;
    # the task's amend detection compares against `git log -1 --pretty=%B`.
    message = "(SIMP-1234) update baseline\n\ndetails\n"

    File.write(File.join(@repo, 'first'), "a\n")
    run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => message)

    File.write(File.join(@repo, 'second'), "b\n")
    _stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => message)

    expect(status).to be_success, stderr
    expect(git('rev-list', '--count', 'HEAD').strip).to eq('2') # initial + one amended commit
    expect(git('ls-tree', '--name-only', 'HEAD').split).to include('first', 'second')
  end

  it 'exits cleanly and leaves HEAD alone when there is nothing to commit' do
    head_before = git('rev-parse', 'HEAD')

    _stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => 'no-op run')

    expect(status).to be_success, stderr
    expect(git('rev-parse', 'HEAD')).to eq(head_before)
  end

  it 'fails when repo_path is missing' do
    _stdout, _stderr, status = run_task('git_commit.rb', 'commit_message' => 'x')
    expect(status).not_to be_success
  end
end
