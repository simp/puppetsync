# Static .travis.yml file for Puppet modules.
#
# Specific modules can provide their own .travis.yml file using the filename
# convention::
#
# @example:
#
#     files/pupmod/_travis.pupmod-simp-xxx.yaml
#
class profile::pupmod::travis_yml {
  file{ "${::repo_path}/.travis.yml":
    content => file(
      "profile/pupmod/_travis.${facts['module_metadata']['name']}.yml",
      'profile/pupmod/_travis.yml'
    ),
  }
}
