# Manages .puppet-lint.rc
#
# @param mode
#   `enforce` (default): this file carries no externally-managed values, so
#   its content is fully managed
class profile::pupmod::puppet_lint(
  Stdlib::Absolutepath        $puppet_lint_rc_path = "${::repo_path}/.puppet-lint.rc",
  Optional[String[1]]         $target_module_name = $facts.dig('module_metadata','name'),
  Enum['enforce','bootstrap'] $mode = 'enforce',
){
  profile::managed_file{ $puppet_lint_rc_path:
    mode    => $mode,
    content => file(
      "${module_name}/pupmod/_puppet-lint.rc.${target_module_name}",
      "${module_name}/pupmod/_puppet-lint.rc",
    ),
  }
}
