# Manage Puppet modules
class role::pupmod {
  include 'profile::pupmod::base'
  include 'profile::pupmod::travis_yml'
  include 'profile::pupmod::gitlab_ci'
}

