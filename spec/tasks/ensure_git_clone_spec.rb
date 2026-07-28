require 'spec_helper'

describe 'task: ensure_git_clone' do
  def git(dir, *args)
    out, status = Open3.capture2e('git', '-C', dir, *args)
    raise "git #{args.join(' ')} failed:\n#{out}" unless status.success?
    out
  end

  # A local "upstream": a seed working repo pushed into a bare repo
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @seed = File.join(dir, 'seed')
      @upstream = File.join(dir, 'upstream.git')
      @clone = File.join(dir, 'repos', 'myrepo')

      FileUtils.mkdir_p(@seed)
      git(@seed, 'init', '-q', '-b', 'main')
      git(@seed, 'config', 'user.email', 'ci@example.com')
      git(@seed, 'config', 'user.name', 'CI')
      File.write(File.join(@seed, 'README.md'), "hello\n")
      git(@seed, 'add', '-A')
      git(@seed, 'commit', '-qm', 'initial')
      git(@seed, 'clone', '-q', '--bare', @seed, @upstream)

      example.run
    end
  end

  def run_clone_task(extra = {})
    run_task('ensure_git_clone.rb',
             { 'git_url' => @upstream, 'repo_path' => @clone, 'branch' => 'main' }.merge(extra))
  end

  def upstream_commit(message)
    File.write(File.join(@seed, message), "#{message}\n")
    git(@seed, 'add', '-A')
    git(@seed, 'commit', '-qm', message)
    git(@seed, 'push', '-q', @upstream, 'main')
  end

  it 'clones fresh when the path does not exist' do
    stdout, stderr, status = run_clone_task

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('method' => 'cloned')
    expect(File).to exist(File.join(@clone, 'README.md'))
  end

  it 'fetches and resets an existing matching clone to origin state' do
    run_clone_task
    upstream_commit('new-upstream-file')

    # Local noise a previous session could leave behind
    git(@clone, 'checkout', '-q', '-b', 'OLD-SESSION-123')
    File.write(File.join(@clone, 'dirty-untracked'), "x\n")
    File.write(File.join(@clone, 'README.md'), "modified\n")

    stdout, stderr, status = run_clone_task

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('method' => 'updated')
    expect(git(@clone, 'rev-parse', 'HEAD')).to eq(git(@seed, 'rev-parse', 'HEAD'))
    expect(git(@clone, 'branch', '--show-current').strip).to eq('main')
    expect(git(@clone, 'for-each-ref', '--format=%(refname:short)', 'refs/heads').split).to eq(['main'])
    expect(File).not_to exist(File.join(@clone, 'dirty-untracked'))
    expect(File.read(File.join(@clone, 'README.md'))).to eq("hello\n")
  end

  it 'is idempotent when origin has not changed' do
    run_clone_task
    head_before = git(@clone, 'rev-parse', 'HEAD')

    stdout, _stderr, status = run_clone_task

    expect(status).to be_success
    expect(JSON.parse(stdout)).to eq('method' => 'updated')
    expect(git(@clone, 'rev-parse', 'HEAD')).to eq(head_before)
  end

  it 'replaces a mismatched path when clear is true' do
    FileUtils.mkdir_p(@clone)
    File.write(File.join(@clone, 'not-a-repo'), "junk\n")

    stdout, stderr, status = run_clone_task('clear' => true)

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('method' => 'recloned')
    expect(File).not_to exist(File.join(@clone, 'not-a-repo'))
    expect(File).to exist(File.join(@clone, 'README.md'))
  end

  it 'fails on a mismatched path when clear is false' do
    FileUtils.mkdir_p(@clone)
    File.write(File.join(@clone, 'not-a-repo'), "junk\n")

    _stdout, stderr, status = run_clone_task('clear' => false)

    expect(status).not_to be_success
    expect(stderr).to include('not a clone')
    expect(File).to exist(File.join(@clone, 'not-a-repo'))
  end

  it 'fails when required params are missing' do
    _stdout, _stderr, status = run_task('ensure_git_clone.rb', 'repo_path' => @clone)
    expect(status).not_to be_success
  end
end
