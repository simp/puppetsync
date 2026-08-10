require_relative 'plan_spec_helper'

describe 'plan: puppetsync::merge_github_prs' do
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
          'merge_github_prs' => {
            'github_api_delay_seconds' => 0,
            'stages' => ['merge_github_pr_for_each_repo'],
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
    }
  end

  def unwrap(value)
    value.respond_to?(:unwrap) ? value.unwrap : value
  end

  def task_result(target, task, value)
    Bolt::Result.new(target, value: value, action: 'task', object: task)
  end

  def stub_pr_listing(prs)
    allow_task('puppetsync::list_github_prs').return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'prs' => prs, 'count' => prs.size) })
    end
  end

  it 'enumerates the session PRs and merges each one with per-PR params' do
    allow_out_message
    stub_pr_listing(session_prs)
    merges = []
    expect_task('puppetsync::merge_github_pr').be_called_times(2).return do |targets:, task:, params:|
      merges << { 'target' => targets.first.name }.merge(params.transform_values { |v| unwrap(v) })
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'merged' => true) })
    end

    result = run_plan('puppetsync::merge_github_prs', plan_params)

    expect(result.ok?).to be(true), result.value.to_s
    expect(merges.map { |c| c['target'] }).to contain_exactly('repo-a', 'repo-b')
    expect(merges.find { |c| c['target'] == 'repo-a' }).to include(
      'target_repo'   => 'simp/repo-a',
      'target_branch' => 'master', # from the PR's base ref
      'fork_user'     => 'bot-user',
      'fork_branch'   => 'puppetsync/SIMP-TEST',
    )
    expect(merges.find { |c| c['target'] == 'repo-b' }).to include('target_branch' => 'main')
  end

  it 'fails the plan at the summary when a merge fails' do
    allow_out_message
    stub_pr_listing(session_prs)
    allow_task('puppetsync::merge_github_pr').with_targets(['repo-a']).return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'merged' => true) })
    end
    allow_task('puppetsync::merge_github_pr').with_targets(['repo-b'])
                                             .error_with('kind' => 'spec/merge-conflict', 'msg' => 'cannot merge')

    result = run_plan('puppetsync::merge_github_prs', plan_params)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/failures occured/)
  end

  it 'fails fast when the session has no open PRs' do
    allow_out_message
    stub_pr_listing([])

    result = run_plan('puppetsync::merge_github_prs', plan_params)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/No open PRs found/)
  end
end
