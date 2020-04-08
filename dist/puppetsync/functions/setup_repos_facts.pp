function puppetsync::setup_repos_facts(TargetSpec $repos){
  $repos.each |$target| {
    $metadata_json = "${target.vars['repo_path']}/metadata.json"
    $module_metadata = file::exists($metadata_json) ? {
      true    => loadjson($metadata_json),
      default => {},
    }
    $target.add_facts( {'project_types' => []} )

    if ['name','version','author','license','summary','dependencies'].all |$k| {$k in $module_metadata} {
      warning( "Repo is a Puppet module (detected ${metadata_json})" )
      $target.add_facts( {'module_metadata' => $module_metadata } )
      $target.add_facts( {'project_types' => ($target.facts['project_types'] << 'puppet')} )
    }
    if $target.facts['project_types'].empty {
      warning( "Repo for ${target.name} was not detected as any particular kind of project (so no special facts were added)" )
      $target.add_facts({'project_types' => ['unknown']})
    }

    ### warning("==== FACTS for ${target.name}:\n${target.facts.to_yaml.regsubst('^','     ','G')}")
  }
}
