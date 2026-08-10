require_relative 'plan_spec_helper'

describe 'plan: puppetsync::batch' do
  include_context 'puppetsync plan specs'

  # NOTE: expect_plan stubs intercept BEFORE Bolt validates the sub-plan's
  # parameters, so a stubbed run can't catch batch passing a parameter the
  # puppetsync plan doesn't declare (that bug shipped once: jira_username/
  # jira_token lingered in batch after de-jirafication). The exact key-set
  # assertion below is the guard: update it deliberately when the interface
  # changes.
  EXPECTED_SYNC_PARAMS = %w[
    targets project_dir batchlist config repolist extra_gem_path github_token options
  ].freeze

  it 'runs the sync plan once per repolist in the batch, in order' do
    allow_out_message
    repolists_run = []
    expect_plan('puppetsync').be_called_times(2).return do |plan:, params:|
      expect(params.keys).to match_array(EXPECTED_SYNC_PARAMS)
      repolists_run << params['repolist']
      Bolt::PlanResult.new("ran #{params['repolist']}", 'success')
    end

    result = run_plan('puppetsync::batch', {
      'project_dir'    => PROJECT_ROOT,
      'batches_config' => { 'repolists' => ['batch-one', 'batch-two'], 'delay' => 0 },
    })

    expect(result.ok?).to be(true), result.value.to_s
    expect(repolists_run).to eq(['batch-one', 'batch-two'])
  end
end
