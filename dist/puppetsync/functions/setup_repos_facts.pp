# Adds facts to each repo target based on the contents of its (checked-out)
# repository
#
# @return [TargetSpec] The same repos
function puppetsync::setup_repos_facts(
  TargetSpec $repos,
  String[1]  $repo_specific_metadata_dirname = '.repo_metadata',
){
  $repos.each |$target| {
    # Puppet modules
    # ------------------------------------------------------------------------
    $metadata_json = "${target.vars['repo_path']}/metadata.json"
    $module_metadata = file::exists($metadata_json) ? {
      true    => loadjson($metadata_json),
      default => {},
    }
    $target.add_facts( {'project_attributes' => []} )

    if ['name','version','author','license','summary','dependencies'].all |$k| {$k in $module_metadata} {
      warning( "Repo is a Puppet module (detected ${metadata_json})" )
      unless $target.facts.dig('project_type'){ $target.add_facts({'project_type' => 'pupmod'} ) }
      $target.add_facts( {'module_metadata'    => $module_metadata } )
      $target.add_facts( {'project_attributes' => ($target.facts['project_attributes'] << 'pupmod')} )
    }

    # ------------------------------------------------------------------------
    if $target.facts['project_type'].empty {
      warning( "WARNING: ${target.name} project_type remains 'unknown'" )
      $target.add_facts({'project_type' => 'unknown'})
    }


    # Repo-specific sync metadata path
    # ------------------------------------------------------------------------
    $sync_metadata_dir = "${target.vars['repo_path']}/${repo_specific_metadata_dirname}"
    $sync_metadata_dir_val = file::exists($sync_metadata_dir) ? {
      true    => $sync_metadata_dir,
      default => false,
    }
    $target.add_facts({'sync_metadata_dir' => $sync_metadata_dir_val})
  }
  $repos
}
