# Run a block of plan logic as a named, skippable pipeline stage and record
# its results on each Target
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
    if opts && opts.key?('stages') && !(opts['stages'] || []).include?(stage_name)
      Puppet.warning("!!! skipping stage '#{stage_name}'")
      call_function('out::message', "===== SKIPPING PIPELINE STAGE DUE TO CONFIGURATION: #{stage_name}")
      return []
    end

    if opts && opts.key?('list_pipeline_stages') && (opts['list_pipeline_stages'] || false)
      call_function('out::message', "- #{stage_name}")
      return []
    end

    # Only run targets that have succeeded in all stages so far
    Puppet.warning("== Preparing stage '#{stage_name}'")
    ok_targets = targets.select { |repo| repo.vars['puppetsync_stage_results'].all? { |k,v| v['ok']}}

    # Skip targets whose repos needed no changes (see the git_commit task),
    # so no-change repos pass through fork/push/PR stages cleanly
    if opts['skip_unchanged_targets']
      unchanged, ok_targets = ok_targets.partition { |t| t.vars['puppetsync_unchanged'] }
      unless unchanged.empty?
        call_function('out::message', "===== SKIPPING #{unchanged.size} UNCHANGED TARGET(S) FOR STAGE: #{stage_name}")
      end
    end

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
      details = results.is_a?(Array) ? " of [#{results.map(&:class).uniq.join(', ')}] (size: #{results.size})" : ''
      raise Puppet::Error,
            "puppetsync::pipeline_stage('#{stage_name}'): the stage block returned " \
            "#{results.class}#{details}, but a Bolt::Result, Bolt::ResultSet, or " \
            'Array of Bolt::Results is required. Unrecordable results would let ' \
            'failed targets continue through later stages, so this is a fatal error.'
    end
    ok_targets
  end
end
