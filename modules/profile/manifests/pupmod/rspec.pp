# @summary Manages rspec
# @param rspec_path Path to .rspec
# @param spec_helper_path Path to spec_helper.rb
# @param target_module_name Target module name
# @param mode
#   `enforce` (default): these files carry no externally-managed values, so
#   their content is fully managed
class profile::pupmod::rspec (
  # lint:ignore:top_scope_facts
  Stdlib::Absolutepath $rspec_path = "${::repo_path}/.rspec",
  Stdlib::Absolutepath $spec_helper_path = "${::repo_path}/spec/spec_helper.rb",
  # lint:endignore
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
  Enum['enforce','bootstrap'] $mode = 'enforce',
) {
  profile::managed_file { $rspec_path:
    mode    => $mode,
    content => file(
      "${module_name}/pupmod/_rspec.${target_module_name}",
      "${module_name}/pupmod/_rspec",
    ),
  }

  profile::managed_file { $spec_helper_path:
    mode    => $mode,
    content => epp(
      "${module_name}/pupmod/spec/spec_helper.rb.epp",
    ),
  }
}
