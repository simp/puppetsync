require_relative 'plan_spec_helper'

describe 'plan: puppetsync::approve_github_prs' do
  include_context 'puppetsync plan specs'

  let(:session_prs) do
    [
      { 'repo' => 'simp/repo-a', 'number' => 11, 'base' => 'master' },
      { 'repo' => 'simp/repo-b', 'number' => 22, 'base' => 'main' },
    ]
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
      'git'    => { 'feature_branch' => 'puppetsync/SIMP-TEST' },
      'github' => { 'org' => 'simp' },
    }
  end

  def plan_params
    {
      'project_dir'       => PROJECT_ROOT,
      'puppetsync_config' => puppetsync_config,
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

  def stub_pr_listing(prs)
    listing_calls = []
    allow_task('puppetsync::list_github_prs').return do |targets:, task:, params:|
      listing_calls << params.transform_values { |v| unwrap(v) }
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'prs' => prs, 'count' => prs.size) })
    end
    listing_calls
  end

  it 'enumerates the session PRs by branch/author and approves each one' do
    allow_out_message
    listing_calls = stub_pr_listing(session_prs)
    approvals = []
    expect_task('puppetsync::approve_github_pr').be_called_times(2).return do |targets:, task:, params:|
      approvals << { 'target' => targets.first.name }.merge(params.transform_values { |v| unwrap(v) })
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'approved' => true) })
    end

    result = run_plan('puppetsync::approve_github_prs', plan_params)

    expect(result.ok?).to be(true), result.value.to_s
    expect(listing_calls.first).to include(
      'org'         => 'simp',
      'head_branch' => 'puppetsync/SIMP-TEST',
      'author'      => 'bot-user',
    )
    expect(approvals.map { |c| c['target'] }).to contain_exactly('repo-a', 'repo-b')
    expect(approvals.find { |c| c['target'] == 'repo-a' }).to include(
      'target_repo'      => 'simp/repo-a',
      'target_branch'    => 'master', # from the PR's base ref
      'fork_user'        => 'bot-user',
      'fork_branch'      => 'puppetsync/SIMP-TEST',
      'approval_message' => ':+1: specs',
    )
    expect(approvals.find { |c| c['target'] == 'repo-b' }).to include('target_branch' => 'main')
  end

  it 'summarizes and fails the plan when approval fails for a repo' do
    allow_out_message
    stub_pr_listing(session_prs)
    allow_task('puppetsync::approve_github_pr').with_targets(['repo-a']).return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'approved' => true) })
    end
    allow_task('puppetsync::approve_github_pr').with_targets(['repo-b'])
                                               .error_with('kind' => 'spec/approval-denied', 'msg' => 'PR not found')

    result = run_plan('puppetsync::approve_github_prs', plan_params)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/failures occured/)
  end

  it 'fails fast when the session has no open PRs' do
    allow_out_message
    stub_pr_listing([])

    result = run_plan('puppetsync::approve_github_prs', plan_params)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/No open PRs found/)
  end

  it 'skips the approval stage entirely when the config stage list omits it' do
    allow_out_message
    stub_pr_listing(session_prs)
    config = puppetsync_config.dup
    config['puppetsync'] = { 'plans' => { 'approve_github_prs' => { 'stages' => [] } } }

    result = run_plan('puppetsync::approve_github_prs', plan_params.merge('puppetsync_config' => config))

    # No approve-task stub declared: a call would raise
    expect(result.ok?).to be(true), result.value.to_s
  end
end
