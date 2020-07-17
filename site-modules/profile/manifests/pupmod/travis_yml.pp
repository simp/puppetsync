# Static .travis.yml file for Puppet modules.
#
# Specific modules can provide their own .travis.yml file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_travis.pupmod-simp-name.yml
#
class profile::pupmod::travis_yml(
  Stdlib::Absolutepath $target_travis_yml_path = "${::repo_path}/.travis.yml",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){
  file{ $target_travis_yml_path:
    content => file(
      "profile/pupmod/_travis.${target_module_name}.yml",
      'profile/pupmod/_travis.yml'
    ),
  }
}
