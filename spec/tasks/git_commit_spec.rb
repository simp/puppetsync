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

  it 'commits pending changes and reports changed: true' do
    File.write(File.join(@repo, 'new_file'), "content\n")

    stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => 'add new file')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('changed' => true, 'amended' => false)
    expect(git('log', '-1', '--pretty=%s').strip).to eq('add new file')
    expect(git('status', '--porcelain')).to be_empty
  end

  it 'amends the HEAD commit when a multi-line message matches' do
    message = "(SIMP-1234) update baseline\n\ndetails\n"

    File.write(File.join(@repo, 'first'), "a\n")
    run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => message)

    File.write(File.join(@repo, 'second'), "b\n")
    stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => message)

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('changed' => true, 'amended' => true)
    expect(git('rev-list', '--count', 'HEAD').strip).to eq('2') # initial + one amended commit
    expect(git('ls-tree', '--name-only', 'HEAD').split).to include('first', 'second')
  end

  it 'amends the HEAD commit when a single-line message matches' do
    File.write(File.join(@repo, 'first'), "a\n")
    run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => 'single-line message')

    File.write(File.join(@repo, 'second'), "b\n")
    stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => 'single-line message')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('changed' => true, 'amended' => true)
    expect(git('rev-list', '--count', 'HEAD').strip).to eq('2')
  end

  it 'reports changed: false and leaves HEAD alone when there is nothing to commit' do
    head_before = git('rev-parse', 'HEAD')

    stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => 'no-op run')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('changed' => false)
    expect(git('rev-parse', 'HEAD')).to eq(head_before)
  end

  it 'commits normally in a repo with no commits yet (no HEAD to amend)' do
    Dir.mktmpdir do |empty_repo|
      out, status = Open3.capture2e('git', '-C', empty_repo, 'init', '-b', 'main')
      raise out unless status.success?
      Open3.capture2e('git', '-C', empty_repo, 'config', 'user.email', 'ci@example.com')
      Open3.capture2e('git', '-C', empty_repo, 'config', 'user.name', 'CI')
      File.write(File.join(empty_repo, 'first_file'), "content\n")

      stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => empty_repo, 'commit_message' => 'first commit')

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to eq('changed' => true, 'amended' => false)
      count, = Open3.capture2e('git', '-C', empty_repo, 'rev-list', '--count', 'HEAD')
      expect(count.strip).to eq('1')
    end
  end

  it 'fails when the commit itself fails' do
    File.write(File.join(@repo, 'new_file'), "content\n")

    # An empty commit message makes `git commit` abort
    _stdout, stderr, status = run_task('git_commit.rb', 'repo_path' => @repo, 'commit_message' => "\n")

    expect(status).not_to be_success
    expect(stderr).to include('failed')
  end

  it 'fails when repo_path does not exist' do
    _stdout, _stderr, status = run_task('git_commit.rb', 'repo_path' => '/nonexistent/path', 'commit_message' => 'x')
    expect(status).not_to be_success
  end

  it 'fails when repo_path is missing' do
    _stdout, _stderr, status = run_task('git_commit.rb', 'commit_message' => 'x')
    expect(status).not_to be_success
  end
end
