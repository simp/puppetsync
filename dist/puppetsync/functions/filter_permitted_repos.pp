function puppetsync::filter_permitted_repos(
  TargetSpec $pf_repos,
  Hash $puppetsync_config,
){
  $permitted_project_types = $puppetsync_config.dig('puppetsync','permitted_project_types').lest || {[]}
  $pf_repos.filter |$repo| {
    if ($repo.facts.dig('project_type') in $permitted_project_types) {
      true
    } else {
      warning(
        sprintf(
          "== WARNING: Rejecting target '%s'  from repos because its project_type (%s) is not in the permitted project_types (%s)",
          $repo.name,
          ($repo.facts.dig('project_type').lest || {''}),
          $permitted_project_types.join(", ")
        )
      )
      false
    }
  }
}

