# Adds facts to each repo target based on the contents of its (checked-out)
# repository
#
# ### Regarding the `project_type` fact
# Each repo's *project_type* is determined in the following order of precedence
# (first match wins:)
#
# 1. **`pupmod`** ― when there is a top-level `metadata.json` file that contains
#    the required keys for Puppet module manifests, as documented at [0]
# 2. **`pupmod_skeleton`** ― when `skeleton/metadata.json.erb` exists
# 3. **`rubygem`** ― when `*.gemspec` exists
# 3. **`simp_unknown`** ― when the repo name starts with `simp-`
#
#
# [0]: https://puppet.com/docs/puppet/latest/modules_metadata.html#modules_metadata_json_keys
#
# @params repos Target objects for each locally checked-out git repo to consider
# @return [TargetSpec] The same repos, now with facts
function puppetsync::setup_repos_facts(
  TargetSpec $repos,
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

    $fixtures = "${target.vars['repo_path']}/.fixtures.yml"
    $module_fixtures = file::exists($fixtures) ? {
      true    => loadyaml($fixtures),
      default => {},
    }
    $target.add_facts({ 'module_fixtures' => $module_fixtures })

    if (
      file::exists("${target.vars['repo_path']}/.fixtures.yml") and (
        $module_fixtures.dig('fixtures', 'repositories', 'compliance_markup') or
        $module_fixtures.dig('fixtures', 'forge_modules', 'compliance_markup')
      )
    ) {
      $target.add_facts({ 'sce_enabled' => true })
    } else {
      $target.add_facts({ 'sce_enabled' => false })
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

    # simp_unknown (no type yet, but either:
    #   * repo name is `pkg-r10k`
    #   * repo name starts with 'simp-'
    #   * repo_url_path (e.g., the path after `github.com/`) starts with simp/
    # )
    # ------------------------------------------------------------------------
    if ($target.facts['project_type'].empty and (
      $target.vars['mod_data']['repo_name'] == 'pkg-r10k' or
      $target.vars['mod_data']['repo_name'].match(/^simp-/) or
      $target.vars['repo_url_path'].match(/^simp\//)
    )){
      unless $target.facts.dig('project_type'){
        $target.add_facts({'project_type' => 'simp_unknown'})
      }
    }

    # unknown
    # ------------------------------------------------------------------------
    if $target.facts['project_type'].empty {
      warning( "WARNING: ${target.name} project_type remains 'unknown'" )
      $target.add_facts({'project_type' => 'unknown'})
    }
  }
  $repos
}
