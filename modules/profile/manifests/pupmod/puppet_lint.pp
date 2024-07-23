# @summary Manages .puppet-lint.rc
# @param puppet_lint_rc_path
# @param target_module_name
class profile::pupmod::puppet_lint (
  Stdlib::Absolutepath $puppet_lint_rc_path = "${::repo_path}/.puppet-lint.rc", # lint:ignore:top_scope_facts
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
) {
  file { $puppet_lint_rc_path:
    content => file(
      "${module_name}/pupmod/_puppet-lint.rc.${target_module_name}",
      "${module_name}/pupmod/_puppet-lint.rc",
    ),
  }
}
