require 'bolt_spec/run'
require 'json'
require 'yaml'

class RunBolt
  include BoltSpec::Run

  # Set config and inventory for BoltSpec
  def bolt_config
    {
      'modulepath' => [ File.join(__dir__,'dist'), File.join(__dir__,'modules') ],
      'log' => {'console' => { 'level' => 'error' }}
    }
  end

  def bolt_inventory
    YAML.load_file( 'inventory.yaml' )
  end
end

runner = RunBolt.new
# Run task to write content to file
results = runner.run_plan('puppetsync::stage_test', {})
# Iterate over array of result hashes and store the failures
failed_results = results.each_with_object([]) do |res, arr|
  res = Hash[[res]]
  if res['status'] == 'success'
    # Upon sucessful task completion run command to show what was printed to file
    #command_results = runner.run_command("cat #{test_file}", 'sample_target')
    #puts JSON.pretty_generate(command_results)
  else
    arr << res
  end
end
# Print any failures (or presumably retry, etc)
failed_results.each { |r| puts JSON.pretty_generate(r) } if failed_results.any?
