# Manage ONLY GitHub Action-related files in Puppet modules
class role::pupmod_github_actions_only {
  include 'profile::pupmod::base'
  include 'profile::pupmod::github_actions'
}

