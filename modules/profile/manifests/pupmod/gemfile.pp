# Baseline Gemfile for Puppet modules
#
# @param strategy
#   `bootstrap` (default): the Gemfile is only laid down when it doesn't
#   exist, so Renovate-managed gem pins in existing repos are never
#   clobbered. Set to `enforce` (e.g. per project_type in Hiera) to
#   overwrite existing files.
class profile::pupmod::gemfile(
  Stdlib::Absolutepath        $gemfile_path = "${::repo_path}/Gemfile",
  Optional[String[1]]         $target_module_name = $facts.dig('module_metadata','name'),
  Enum['enforce','bootstrap'] $strategy = 'bootstrap',
){
  profile::managed_file{ $gemfile_path:
    strategy => $strategy,
    content => file(
      "${module_name}/pupmod/Gemfile.${target_module_name}",
      "${module_name}/pupmod/Gemfile",
    ),
  }

  file{ "${gemfile_path}.lock":
    ensure => absent,
  }
}
