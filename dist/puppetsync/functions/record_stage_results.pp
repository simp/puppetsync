# Record a stage's results under in its Target(s)' variables.
#
# The results are added to each target's `.var['puppetsync_stage_results']` Hash
#
# @summary Record a stage's results in its Target(s) variables
# @return
function puppetsync::record_stage_results(
  String[1] $stage_name,
  Variant[ApplyResult,ResultSet,Result,Array[Result],Array[ResultSet]] $results
) {
  case $results {
    # lint:ignore:unquoted_string_in_case
    Array[Result]: {
      warning( "** puppetsync::record_stage_results (${stage_name}): Array[Result], ResultSet" )
      $results.each |$result| { puppetsync::record_stage_results($stage_name, $result) }
    }

    ResultSet: {
      warning( "** puppetsync::record_stage_results (${stage_name}): Array[Result], ResultSet" )
      $results.results.each |$result| { puppetsync::record_stage_results($stage_name, $result) }
    }

    ApplyResult, Result: {
      warning( "** puppetsync::record_stage_results (${stage_name}): ApplyResult, Result)" )
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
      warning( "** puppetsync::record_stage_results (${stage_name}): Array[ResultSet]" )
      $results.each |$resultset| { puppetsync::record_stage_results($stage_name, $resultset) }
    }

    default: {
      out::message("+++++++ DEFAULT puppetsync::record_stage_results (\$result = Tuple?)")
      debug::break()
    }
    # lint:endignore
  }
}
