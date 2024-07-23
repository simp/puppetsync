# Parse Puppetfile contents
Puppet::Functions.create_function(:'puppetsync::pipeline_stage') do
  dispatch :pipeline_stage do
    param 'Boltlib::TargetSpec', :targets
    param 'String', :stage_name
    optional_param 'Hash', :opts
    block_param 'Callable', :code
    return_type 'Boltlib::TargetSpec'
  end

  def pipeline_stage(targets, stage_name, opts = {}, &code)
    # Skip stage
    if opts&.key?('stages') && !opts['stages']&.include?(stage_name)
      Puppet.warning("!!! skipping stage '#{stage_name}'")
      call_function('out::message', "===== SKIPPING PIPELINE STAGE DUE TO CONFIGURATION: #{stage_name}")
      return []
    end

    if opts&.key?('list_pipeline_stages') && opts['list_pipeline_stages']
      call_function('out::message', "- #{stage_name}")
      return []
    end

    # Only run targets that have succeeded in all stages so far
    Puppet.warning("== Preparing stage '#{stage_name}'")
    ok_targets = targets.select { |repo| repo.vars['puppetsync_stage_results'].all? { |_k, v| v['ok'] } }

    # Run stage block
    Puppet.warning('filtered ok stages before running')
    results = yield(ok_targets, stage_name)

    if results.class == Array && results.all? { |x| x.class == Bolt::Result }
      Puppet.warning("++++++++ puppetsync::pipeline_stage (stage: #{stage_name}): converting Array of Bolt::Results into a Bolt::ResultSet")
      results = Bolt::ResultSet.new(results)
    end

    if results.is_a?(Bolt::ResultSet) || results.is_a?(Bolt::Result)
      call_function('out::message', "puppetsync::record_stage_results( #{stage_name}, #{results.class})")
      call_function('puppetsync::record_stage_results', stage_name, results)
    else
      STDERR.puts '############ WARNING: results are NOT a Bolt::Result'
      Puppet.warning "############ WARNING: results are NOT a Bolt::Result (file:#{__FILE__}, stage: #{stage_name}, class: #{results.class}"
      if results.is_a? Array
        Puppet.warning "############ WARNING: ARRAY.size: #{results.size}"
        Puppet.warning "############ WARNING: ARRAY.first class: #{results.first.class}"
      end

      begin
        require 'pry'
        binding.pry # rubocop:disable Lint/Debugger
      rescue LoadError => e
        puts '==============================================================', e.message
      end
    end
    ok_targets
  end
end
