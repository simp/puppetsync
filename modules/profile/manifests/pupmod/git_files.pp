# Manages .gitignore and .gitattributes
class profile::pupmod::git_files(
  Stdlib::Absolutepath $gitignore_path = "${::repo_path}/.gitignore",
  Stdlib::Absolutepath $gitattributes_path = "${::repo_path}/.gitattributes",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){
  file{ $gitignore_path:
    content => file(
      "${module_name}/pupmod/_gitignore.${target_module_name}",
      "${module_name}/pupmod/_gitignore",
    ),
  }

  file{ $gitattributes_path:
    content => file(
      "${module_name}/pupmod/_gitattributes.${target_module_name}",
      "${module_name}/pupmod/_gitattributes",
    ),
  }
}
