# @summary Ensure that obsolete files are removed
#
# @param files
# @param repo_path
#
# Use Hiera to build up a $files array
class profile::obsoletes (
  Array[String[1]] $files = [],
  Stdlib::Absolutepath $repo_path = $::repo_path, # lint:ignore:top_scope_facts
) {
  file { $files.map |$file| { "${repo_path}/${file}" }:
    ensure => absent,
    force  => true,
  }
}
