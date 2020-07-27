# Manage Puppet modules
class role::pupmod {
  include 'profile::pupmod::base'
  include 'profile::pupmod::travis_yml'
  include 'profile::pupmod::gitlab_ci'
  include 'profile::pupmod::gemfile'
  #include 'profile::pupmod::rspec'
  #include 'profile::pupmod::git_files'
  #include 'profile::pupmod::puppet_lint'
}

