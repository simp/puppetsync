# @summary Static Gemfile for Puppet modules
# @param gemfile_path
# @param target_module_name
class profile::pupmod::gemfile (
  Stdlib::Absolutepath $gemfile_path = "${::repo_path}/Gemfile", # lint:ignore:top_scope_facts
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
) {
  file { $gemfile_path:
    content => file(
      "${module_name}/pupmod/Gemfile.${target_module_name}",
      "${module_name}/pupmod/Gemfile",
    ),
  }

  file { "${gemfile_path}.lock":
    ensure => absent,
  }
}
