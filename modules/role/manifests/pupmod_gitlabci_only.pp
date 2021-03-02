# Manage ONLY GitLab CI-related files in Puppet modules
class role::pupmod_gitlabci_only {
  include 'profile::pupmod::base'
  include 'profile::pupmod::gitlab_ci'
}

