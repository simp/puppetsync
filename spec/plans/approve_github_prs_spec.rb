require_relative 'plan_spec_helper'

describe 'plan: puppetsync::approve_github_prs' do
  include_context 'puppetsync plan specs'

  let(:repos_config) do
    {
      'https://github.com/simp/repo-a' => { 'branch' => 'master' },
      'https://github.com/simp/repo-b' => { 'branch' => 'main' },
    }
  end

  let(:puppetsync_config) do
    {
      'puppetsync' => {
        'plans' => {
          'approve_github_prs' => {
            'github_api_delay_seconds' => 0,
            'stages' => ['approve_github_pr_for_each_repo'],
          },
        },
      },
      'git' => { 'feature_branch' => 'SIMP-TEST' },
    }
  end

  def plan_params
    {
      'puppetsync_config' => puppetsync_config,
      'repos_config'      => repos_config,
      'pr_user'           => 'bot-user',
      'approval_message'  => ':+1: specs',
    }
  end

  # Task metadata marks some params sensitive, so Bolt wraps them before the
  # stub sees them
  def unwrap(value)
    value.respond_to?(:unwrap) ? value.unwrap : value
  end

  def task_result(target, task, value)
    Bolt::Result.new(target, value: value, action: 'task', object: task)
  end

  it 'approves the PR for every repo with per-repo params from the repolist' do
    allow_out_message
    calls = []
    expect_task('puppetsync::approve_github_pr').be_called_times(2).return do |targets:, task:, params:|
      calls << { 'target' => targets.first.name }.merge(params.transform_values { |v| unwrap(v) })
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'approved' => true) })
    end

    result = run_plan('puppetsync::approve_github_prs', plan_params)

    expect(result.ok?).to be(true), result.value.to_s
    expect(calls.map { |c| c['target'] }).to contain_exactly('repo-a', 'repo-b')
    repo_a = calls.find { |c| c['target'] == 'repo-a' }
    expect(repo_a).to include(
      'target_repo'      => 'simp/repo-a',
      'target_branch'    => 'master',
      'fork_user'        => 'bot-user',
      'fork_branch'      => 'SIMP-TEST',
      'approval_message' => ':+1: specs',
      'github_authtoken' => ENV.fetch('GITHUB_API_TOKEN'),
    )
    repo_b = calls.find { |c| c['target'] == 'repo-b' }
    expect(repo_b).to include('target_repo' => 'simp/repo-b', 'target_branch' => 'main')
  end

  it 'summarizes and fails the plan when approval fails for a repo' do
    allow_out_message
    allow_task('puppetsync::approve_github_pr').with_targets(['repo-a']).return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'approved' => true) })
    end
    allow_task('puppetsync::approve_github_pr').with_targets(['repo-b'])
                                               .error_with('kind' => 'spec/approval-denied', 'msg' => 'PR not found')

    result = run_plan('puppetsync::approve_github_prs', plan_params)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/failures occured/)
  end

  it 'skips the approval stage entirely when the config stage list omits it' do
    allow_out_message
    config = puppetsync_config.dup
    config['puppetsync'] = { 'plans' => { 'approve_github_prs' => { 'stages' => [] } } }

    result = run_plan('puppetsync::approve_github_prs', plan_params.merge('puppetsync_config' => config))

    # No task stubs declared: any approve/install task call would raise
    expect(result.ok?).to be(true), result.value.to_s
  end
end
