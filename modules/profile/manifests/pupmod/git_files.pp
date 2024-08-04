# @summary Manages .gitignore and .gitattributes
# @param gitignore_path
# @param gitattributes_path
# @param target_module_name
class profile::pupmod::git_files (
  Stdlib::Absolutepath $gitignore_path = "${::repo_path}/.gitignore", # lint:ignore:top_scope_facts
  Stdlib::Absolutepath $gitattributes_path = "${::repo_path}/.gitattributes", # lint:ignore:top_scope_facts
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
) {
  file { $gitignore_path:
    content => file(
      "${module_name}/pupmod/_gitignore.${target_module_name}",
      "${module_name}/pupmod/_gitignore",
      "${module_name}/_gitignore",
    ),
  }

  file { $gitattributes_path:
    content => file(
      "${module_name}/pupmod/_gitattributes.${target_module_name}",
      "${module_name}/pupmod/_gitattributes",
      "${module_name}/_gitattributes",
    ),
  }
}
