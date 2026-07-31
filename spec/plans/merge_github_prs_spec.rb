require_relative 'plan_spec_helper'

describe 'plan: puppetsync::merge_github_prs' do
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
          'merge_github_prs' => {
            'github_api_delay_seconds' => 0,
            'stages' => ['merge_github_pr_for_each_repo'],
          },
        },
      },
      'git' => { 'feature_branch' => 'SIMP-TEST' },
    }
  end

  def plan_params
    {
      'project_dir'       => PROJECT_ROOT,
      'puppetsync_config' => puppetsync_config,
      'repos_config'      => repos_config,
      'pr_user'           => 'bot-user',
    }
  end

  def unwrap(value)
    value.respond_to?(:unwrap) ? value.unwrap : value
  end

  def task_result(target, task, value)
    Bolt::Result.new(target, value: value, action: 'task', object: task)
  end

  it 'merges the PR for every repo with per-repo params from the repolist' do
    allow_out_message
    calls = []
    expect_task('puppetsync::merge_github_pr').be_called_times(2).return do |targets:, task:, params:|
      calls << { 'target' => targets.first.name }.merge(params.transform_values { |v| unwrap(v) })
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'merged' => true) })
    end

    result = run_plan('puppetsync::merge_github_prs', plan_params)

    expect(result.ok?).to be(true), result.value.to_s
    expect(calls.map { |c| c['target'] }).to contain_exactly('repo-a', 'repo-b')
    expect(calls.find { |c| c['target'] == 'repo-a' }).to include(
      'target_repo'   => 'simp/repo-a',
      'target_branch' => 'master',
      'fork_user'     => 'bot-user',
      'fork_branch'   => 'SIMP-TEST',
    )
    expect(calls.find { |c| c['target'] == 'repo-b' }).to include('target_branch' => 'main')
  end

  it 'fails the plan at the summary when a merge fails' do
    allow_out_message
    allow_task('puppetsync::merge_github_pr').with_targets(['repo-a']).return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'merged' => true) })
    end
    allow_task('puppetsync::merge_github_pr').with_targets(['repo-b'])
                                             .error_with('kind' => 'spec/merge-conflict', 'msg' => 'cannot merge')

    result = run_plan('puppetsync::merge_github_prs', plan_params)

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/failures occured/)
  end
end
