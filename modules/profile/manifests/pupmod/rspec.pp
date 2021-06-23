# Manages .rspec
class profile::pupmod::rspec(
  Stdlib::Absolutepath $rspec_path = "${::repo_path}/.rspec",
  Optional[String[1]]  $target_module_name = $facts.dig('module_metadata','name'),
){
  file{ $rspec_path:
    content => file(
      "${module_name}/pupmod/_rspec.${target_module_name}",
      "${module_name}/pupmod/_rspec",
    ),
  }
}
