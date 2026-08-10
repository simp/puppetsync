require 'spec_helper'

describe 'task: list_github_prs' do
  def run_list(params)
    stdout, stderr, status = run_task('list_github_prs.rb', params)
    [stdout, stderr, status]
  end

  it 'passes through injected PR records, sorted by repo' do
    prs = [
      { 'repo' => 'simp/zzz', 'number' => 3, 'base' => 'main' },
      { 'repo' => 'simp/aaa', 'number' => 1, 'base' => 'master' },
    ]
    stdout, stderr, status = run_list('prs' => prs)

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result['count']).to eq(2)
    expect(result['prs'].map { |pr| pr['repo'] }).to eq(['simp/aaa', 'simp/zzz'])
  end

  it 'fails without an org when no PR records are injected' do
    _stdout, _stderr, status = run_list('head_branch' => 'x')
    expect(status).not_to be_success
  end

  it 'fails without a head_branch when no PR records are injected' do
    _stdout, _stderr, status = run_list('org' => 'simp')
    expect(status).not_to be_success
  end
end
