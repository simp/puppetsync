# Manages .ruby-version
class profile::pupmod::ruby_version(
  Stdlib::Absolutepath $ruby_version_path = "${::repo_path}/.ruby-version",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){
  file{ $ruby_version_path: ensure => absent, }
}
