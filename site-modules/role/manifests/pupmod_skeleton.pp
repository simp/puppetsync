# Manage Puppet module skeleton
class role::pupmod_skeleton {
  # paths to /skeleton are handled in Hiera
  include 'profile::pupmod::gitlab_ci'
  include 'profile::pupmod::gemfile'
  include 'profile::pupmod::travis_yml'
}

