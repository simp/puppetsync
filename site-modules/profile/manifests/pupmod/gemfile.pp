# Static Gemfile for Puppet modules
class profile::pupmod::gemfile {
  file{ "${::repo_path}/Gemfile":
    content => file( 'profile/pupmod/Gemfile' ),
  }

  file{ "${::repo_path}/Gemfile.lock":
    ensure => absent,
  }
}
