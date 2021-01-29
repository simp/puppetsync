# Manage Puppet modules
class role::pupmod {
  include 'profile::pupmod::base'
  include 'profile::pupmod::github_actions'
  include 'profile::pupmod::gitlab_ci'
  include 'profile::pupmod::gemfile'
  include 'profile::pupmod::git_files'
  include 'profile::pupmod::puppet_lint'
  include 'profile::pupmod::rspec'
  include 'profile::pupmod::pmtignore'
  include 'profile::obsoletes'
}
