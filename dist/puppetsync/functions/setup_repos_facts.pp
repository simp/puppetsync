# Adds facts to each repo target based on the contents of its (checked-out)
# repository
#
# @return [TargetSpec] The same repos
function puppetsync::setup_repos_facts(
  TargetSpec $repos,
  String[1]  $repo_specific_metadata_dirname = '.repo_metadata',
){
  $repos.each |$target| {
    $target.add_facts( {'project_attributes' => []} )

    # pupmod
    # ------------------------------------------------------------------------
    $metadata_json = "${target.vars['repo_path']}/metadata.json"
    $module_metadata = file::exists($metadata_json) ? {
      true    => loadjson($metadata_json),
      default => {},
    }

    if ['name','version','author','license','summary','dependencies'].all |$k| {$k in $module_metadata} {
      warning( "Repo is a Puppet module (detected ${metadata_json})" )
      unless $target.facts.dig('project_type'){ $target.add_facts({'project_type' => 'pupmod'} ) }
      $target.add_facts( {'module_metadata'    => $module_metadata } )
      $target.add_facts( {'project_attributes' => ($target.facts['project_attributes'] << 'pupmod')} )
    }

    # pupmod_skeleton
    # ------------------------------------------------------------------------
    $skeleton_metadata_json = "${target.vars['repo_path']}/skeleton/metadata.json.erb"
    if ($target.facts['project_type'].empty and file::exists($skeleton_metadata_json)){
      warning( "Repo is a Puppet module Skeleton (detected ${skeleton_metadata_json})" )
      unless $target.facts.dig('project_type'){ $target.add_facts({'project_type' => 'pupmod_skeleton'} ) }
      $target.add_facts( {'project_attributes' => ($target.facts['project_attributes'] << 'pupmod_skeleton')} )
    }

    # rubygem
    # ------------------------------------------------------------------------
    $gemspecs = glob( [ "${target.vars['repo_path']}/*.gemspec" ] )
    if !$gemspecs.empty {
      warning( "Repo is a RubyGem (detected ${gemspecs.join(', ')})" )
      $gemspec_var = file($gemspecs[0]).match(/Gem::Specification\.new *do *\|(.*?)\|/)[1]
      #$gem_name = file($gemspecs[0]).split(/${gemspec_var}.name *= */)[1].split(/\"/)[1]
      $gem_name = file($gemspecs[0]).split("${gemspec_var}.name ")[1].split(/ *= *['"]/)[1].split(/['"]/)[0]
      $target.add_facts( {'gem_name' => $gem_name })
      unless $target.facts.dig('project_type'){ $target.add_facts({'project_type' => 'rubygem'}) }
      $target.add_facts( {'project_attributes' => ($target.facts['project_attributes'] << 'rubygem')} )
    }

    # simp_unknown (no type yet, but repo name starts with 'simp-')
    # ------------------------------------------------------------------------
    if ($target.facts['project_type'].empty and $target.vars['mod_data']['repo_name'].match(/^simp-/)) {
      unless $target.facts.dig('project_type'){ $target.add_facts({'project_type' => 'simp_unknown'}) }
    }

    # unknown
    # ------------------------------------------------------------------------
    if $target.facts['project_type'].empty {
      warning( "WARNING: ${target.name} project_type remains 'unknown'" )
      $target.add_facts({'project_type' => 'unknown'})
    }

    ### # NOTE this may not be needed yet
    ###
    ### # Repo-specific sync metadata path
    ### # ------------------------------------------------------------------------
    ### $sync_metadata_dir = "${target.vars['repo_path']}/${repo_specific_metadata_dirname}"
    ### $sync_metadata_dir_val = file::exists($sync_metadata_dir) ? {
    ###   true    => $sync_metadata_dir,
    ###   default => false,
    ### }
    ### $target.add_facts({'sync_metadata_dir' => $sync_metadata_dir_val})
  }
  $repos
}
