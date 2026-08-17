require_relative 'plan_spec_helper'

describe 'plan: puppetsync::set_github_pr_state' do
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
          'set_github_pr_state' => {
            'github_api_delay_seconds' => 0,
            'stages' => ['set_github_pr_state_for_each_repo'],
          },
        },
      },
      'git'    => { 'feature_branch' => 'puppetsync/SIMP-TEST' },
      'github' => { 'org' => 'simp' },
    }
  end

  def plan_params(state)
    {
      'state'             => state,
      'project_dir'       => PROJECT_ROOT,
      'puppetsync_config' => puppetsync_config,
      'pr_user'           => 'bot-user',
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

  it 'enumerates the session PRs and marks each one as draft' do
    allow_out_message
    listing_calls = stub_pr_listing(session_prs)
    flips = []
    expect_task('puppetsync::set_github_pr_state').be_called_times(2).return do |targets:, task:, params:|
      flips << { 'target' => targets.first.name }.merge(params.transform_values { |v| unwrap(v) })
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'changed' => true, 'draft' => true) })
    end

    result = run_plan('puppetsync::set_github_pr_state', plan_params('draft'))

    expect(result.ok?).to be(true), result.value.to_s
    expect(listing_calls.first).to include(
      'org'         => 'simp',
      'head_branch' => 'puppetsync/SIMP-TEST',
      'author'      => 'bot-user',
    )
    expect(flips.map { |c| c['target'] }).to contain_exactly('repo-a', 'repo-b')
    expect(flips.find { |c| c['target'] == 'repo-a' }).to include(
      'target_repo'   => 'simp/repo-a',
      'target_branch' => 'master', # from the PR's base ref
      'fork_user'     => 'bot-user',
      'fork_branch'   => 'puppetsync/SIMP-TEST',
      'state'         => 'draft',
    )
    expect(flips.find { |c| c['target'] == 'repo-b' }).to include('target_branch' => 'main')
  end

  it "passes state 'ready' through to the task" do
    allow_out_message
    stub_pr_listing(session_prs)
    states = []
    expect_task('puppetsync::set_github_pr_state').be_called_times(2).return do |targets:, task:, params:|
      states << unwrap(params['state'])
      Bolt::ResultSet.new(targets.map { |t| task_result(t, task, 'changed' => false, 'draft' => false) })
    end

    result = run_plan('puppetsync::set_github_pr_state', plan_params('ready'))

    expect(result.ok?).to be(true), result.value.to_s
    expect(states).to eq(%w[ready ready])
  end

  it 'fails fast when the session has no open PRs' do
    allow_out_message
    stub_pr_listing([])

    result = run_plan('puppetsync::set_github_pr_state', plan_params('draft'))

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/No open PRs found/)
  end

  it 'rejects states other than draft/ready' do
    result = run_plan('puppetsync::set_github_pr_state', plan_params('closed'))

    expect(result.ok?).to be(false)
    expect(result.value.msg).to match(/state/)
  end
end
