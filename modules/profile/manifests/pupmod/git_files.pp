# Manages .gitignore and .gitattributes
#
# @param mode
#   `enforce` (default): these files carry no externally-managed values, so
#   their content is fully managed
class profile::pupmod::git_files(
  Stdlib::Absolutepath        $gitignore_path = "${::repo_path}/.gitignore",
  Stdlib::Absolutepath        $gitattributes_path = "${::repo_path}/.gitattributes",
  Optional[String[1]]         $target_module_name = $facts.dig('module_metadata','name'),
  Enum['enforce','bootstrap'] $mode = 'enforce',
){
  profile::managed_file{ $gitignore_path:
    mode    => $mode,
    content => file(
      "${module_name}/pupmod/_gitignore.${target_module_name}",
      "${module_name}/pupmod/_gitignore",
      "${module_name}/_gitignore",
    ),
  }

  profile::managed_file{ $gitattributes_path:
    mode    => $mode,
    content => file(
      "${module_name}/pupmod/_gitattributes.${target_module_name}",
      "${module_name}/pupmod/_gitattributes",
      "${module_name}/_gitattributes",
    ),
  }
}
