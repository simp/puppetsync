require_relative 'plan_spec_helper'

describe 'plan: puppetsync::batch' do
  include_context 'puppetsync plan specs'

  it 'runs the sync plan once per repolist in the batch, in order' do
    allow_out_message
    repolists_run = []
    expect_plan('puppetsync').be_called_times(2).return do |plan:, params:|
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
