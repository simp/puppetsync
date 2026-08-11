require 'spec_helper'

# The real task shells out to bundler (network, gem installs), so these
# specs substitute a fake BUNDLER_EXE that mimics the two calls the task
# makes: `bundle install --quiet` and
# `bundle exec rake strings:generate:reference`.
describe 'task: generate_reference_md' do
  def git(*args)
    out, status = Open3.capture2e('git', '-C', @repo, *args)
    raise "git #{args.join(' ')} failed:\n#{out}" unless status.success?
    out
  end

  def fake_bundler(script_body)
    path = File.join(@dir, 'fake_bundle')
    File.write(path, "#!/bin/bash\n#{script_body}\n")
    File.chmod(0o755, path)
    path
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @repo = File.join(dir, 'pupmod-simp-example')
      Dir.mkdir(@repo)
      git('init', '-b', 'main')
      git('config', 'user.email', 'ci@example.com')
      git('config', 'user.name', 'CI')
      File.write(File.join(@repo, 'REFERENCE.md'), "old reference\n")
      git('add', '-A')
      git('commit', '-m', 'initial')
      example.run
    end
  end

  it 'regenerates REFERENCE.md and reports changed: true when it moves' do
    bundler = fake_bundler('[ "$1" = "exec" ] && echo "new reference" > REFERENCE.md; exit 0')

    stdout, stderr, status = run_task('generate_reference_md.rb',
                                      { 'repo_path' => @repo },
                                      { 'BUNDLER_EXE' => bundler })

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('changed' => true)
    expect(File.read(File.join(@repo, 'REFERENCE.md'))).to eq("new reference\n")
    # No self-commit: the change is left for the git_commit_changes stage
    expect(git('status', '--porcelain')).to include('REFERENCE.md')
  end

  it 'reports changed: false when regeneration reproduces HEAD' do
    bundler = fake_bundler('[ "$1" = "exec" ] && echo "old reference" > REFERENCE.md; exit 0')

    stdout, stderr, status = run_task('generate_reference_md.rb',
                                      { 'repo_path' => @repo },
                                      { 'BUNDLER_EXE' => bundler })

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq('changed' => false)
    expect(git('status', '--porcelain')).to be_empty
  end

  it 'fails when bundler fails, including its output' do
    bundler = fake_bundler('echo "Could not find gem" >&2; exit 1')

    _stdout, stderr, status = run_task('generate_reference_md.rb',
                                       { 'repo_path' => @repo },
                                       { 'BUNDLER_EXE' => bundler })

    expect(status).not_to be_success
    expect(stderr).to include('Could not find gem')
  end

  it 'fails when no REFERENCE.md exists after regeneration' do
    File.delete(File.join(@repo, 'REFERENCE.md'))
    bundler = fake_bundler('exit 0')

    _stdout, stderr, status = run_task('generate_reference_md.rb',
                                       { 'repo_path' => @repo },
                                       { 'BUNDLER_EXE' => bundler })

    expect(status).not_to be_success
    expect(stderr).to include('no REFERENCE.md')
  end

  it 'fails when repo_path is missing' do
    _stdout, _stderr, status = run_task('generate_reference_md.rb', {})
    expect(status).not_to be_success
  end
end
