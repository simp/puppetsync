# Static .pdkignore file for Puppet modules.
#
# Specific modules can provide their own .pdkignore file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_pdkignore.pupmod-simp-name
#
# @param mode
#   `enforce` (default): this file carries no externally-managed values, so
#   its content is fully managed
class profile::pupmod::pdkignore(
  Stdlib::Absolutepath        $target_pdkignore_path = "${::repo_path}/.pdkignore",
  Optional[String[1]]         $target_module_name = $facts.dig('module_metadata','name'),
  Enum['enforce','bootstrap'] $mode = 'enforce',
){
  profile::managed_file{ $target_pdkignore_path:
    mode    => $mode,
    content => file(
      "${module_name}/pupmod/_pdkignore.${target_module_name}",
      "${module_name}/pupmod/_pdkignore"
    ),
  }
}
