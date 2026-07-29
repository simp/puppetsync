require 'spec_helper'

describe 'task: checkout_git_feature_branch_in_each_repo' do
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

  def run_checkout(branch)
    run_task('checkout_git_feature_branch_in_each_repo.rb', 'branch' => branch, 'repo_paths' => [@repo])
  end

  it 'creates the feature branch when it does not exist' do
    stdout, stderr, status = run_checkout('SIMP-0000')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq(@repo => 'created')
    expect(git('branch', '--show-current').strip).to eq('SIMP-0000')
  end

  it 'checks out the feature branch when it already exists' do
    git('branch', 'SIMP-0000')

    stdout, stderr, status = run_checkout('SIMP-0000')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq(@repo => 'checked_out')
    expect(git('branch', '--show-current').strip).to eq('SIMP-0000')
  end

  it 'fails when no branch is given' do
    _stdout, _stderr, status = run_task('checkout_git_feature_branch_in_each_repo.rb', 'repo_paths' => [@repo])
    expect(status).not_to be_success
  end
end
