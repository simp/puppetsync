require_relative 'plan_spec_helper'

describe 'puppetsync::pipeline_stage' do
  include_context 'puppetsync plan specs'

  context 'stage gating and unchanged-target skipping (stage_smoke)' do
    it 'runs gated stages only on changed targets and honors the stage list' do
      expect_command('true').with_targets(['changed-repo'])
      allow_out_message
      expect_out_message.with_params('===== SKIPPING 1 UNCHANGED TARGET(S) FOR STAGE: gated_stage')

      result = run_plan('puppetsync_test::stage_smoke', {})

      expect(result.ok?).to be(true), result.value.to_s
      expect(result.value['ran']).to eq(['changed-repo'])
      expect(result.value['skipped_stage_result']).to eq([])
    end
  end

  context 'failure holdback (stage_holdback)' do
    it 'holds a failed target back from later stages while others proceed' do
      allow_out_message
      allow_command('stage-one').return do |targets:, command:, params:|
        Bolt::ResultSet.new(targets.map do |target|
          exit_code = target.name == 'bad-repo' ? 1 : 0
          value = { 'stdout' => '', 'stderr' => '', 'merged_output' => '', 'exit_code' => exit_code }
          Bolt::Result.for_command(target, value, 'command', command, [])
        end)
      end
      expect_command('stage-two').with_targets(['good-repo'])

      result = run_plan('puppetsync_test::stage_holdback', {})

      expect(result.ok?).to be(true), result.value.to_s
      expect(result.value).to eq(['good-repo'])
    end
  end

  context 'unrecordable results (stage_bad_result)' do
    it 'fails the plan when a stage block returns a non-Bolt-result' do
      allow_out_message

      result = run_plan('puppetsync_test::stage_bad_result', {})

      expect(result.ok?).to be(false)
      expect(result.value.msg).to match(/the stage block returned String/)
    end
  end
end
