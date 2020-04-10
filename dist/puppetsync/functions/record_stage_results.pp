function puppetsync::record_stage_results(
  String[1] $stage_name,
  Variant[ApplyResult,ResultSet,Result,Array[Result],Array[ResultSet]] $results
){
  case $results {
    ###ApplyResult: {
    ###  warning( '** puppetsync::record_stage_results: ApplyResult' )
    ###  $results.results.each |$result| { puppetsync::record_stage_results($stage_name, $result) }
    ###}
    Array[Result]: {
      warning( '** puppetsync::record_stage_results: Array[Result], ResultSet' )
      $results.each |$result| { puppetsync::record_stage_results($stage_name, $result) }
    }

    ResultSet: {
      warning( '** puppetsync::record_stage_results: Array[Result], ResultSet' )
      $results.results.each |$result| { puppetsync::record_stage_results($stage_name, $result) }
    }

    ApplyResult, Result: {
      warning( '** puppetsync::record_stage_results: ApplyResult, Result)' )
      $result = $results
      $stage_result = {
        'ok'   => $result.ok,
        'data' => $result.to_data,
      }
      $merge_results =  $result.target.vars['puppetsync_stage_results'].merge(
        Hash({ $stage_name => Hash($stage_result) })
      )
      $result.target.set_var( 'puppetsync_stage_results', Hash($merge_results) )
    }

    Array[ResultSet]: {
      warning( '** puppetsync::record_stage_results: Array[ResultSet]' )
      $results.each |$resultset| { puppetsync::record_stage_results($stage_name, $resultset) }
    }

    default: {
      out::message("+++++++ DEFAULT puppetsync::record_stage_results (\$result = Tuple?)")
      debug::break()
    }
  }
}
