# Ensure that obsolete files are removed
class profile::pupmod::obsoletes(
  Array[String[1]] $files = [],
  Stdlib::Absolutepath $repo_path = $::repo_path,
){
  file{ $files.map |$file| { "${repo_path}/${file}" }:
    ensure => absent,
    force  => true,
  }
}
