# Static Gemfile for Puppet modules
class profile::pupmod::gemfile(
  Stdlib::Absolutepath $gemfile_path = "${::repo_path}/Gemfile",
){
  file{ $gemfile_path:
    content => file( 'profile/pupmod/Gemfile' ),
  }

  file{ "${gemfile_path}.lock":
    ensure => absent,
  }
}
