# Static .pdkignore file for Puppet modules.
#
# Specific modules can provide their own .pdkignore file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_pdkignore.pupmod-simp-name
#
class profile::pupmod::pdkignore(
  Stdlib::Absolutepath $target_pdkignore_path = "${::repo_path}/.pdkignore",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){
  file{ $target_pdkignore_path:
    content => file(
      "${module_name}/pupmod/_pdkignore.${target_module_name}",
      "${module_name}/pupmod/_pdkignore"
    ),
  }
}
