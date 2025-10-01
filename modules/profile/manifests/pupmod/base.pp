# Common code for all pupmod:: roles
class profile::pupmod::base {
  $project_type = $facts.dig('project_type').lest || { 'unknown' }
  unless $project_type == 'pupmod' or $project_type == 'pupmod_skeleton' {
    fail("ERROR: reached class '${title}', but project_type is not a 'pupmod' (${project_type})")
  }
  $org = $facts.dig('module_metadata','forge_org')
  if $org { warn("======== Forge org: ${org}") }

  # Clean up obsolete puppetsync folder
  file { "${::repo_path}/.repo_metadata": # lint:ignore:top_scope_facts
    ensure => absent,
    force  => true,
  }
}
