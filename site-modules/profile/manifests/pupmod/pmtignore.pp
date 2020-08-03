# Static .pmtignore file for Puppet modules.
#
# Specific modules can provide their own .pmtignore file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_pmtignore.pupmod-simp-name
#
class profile::pupmod::pmtignore(
  Stdlib::Absolutepath $target_pmtignore_path = "${::repo_path}/.pmtignore",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){
  file{ $target_pmtignore_path:
    content => file(
      "profile/pupmod/_pmtignore.${target_module_name}",
      'profile/pupmod/_pmtignore'
    ),
  }
}
