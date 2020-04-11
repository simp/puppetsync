# Manage ONLY .travis.yml in Puppet modules
class role::pupmod_travis_only {
  include 'profile::pupmod::base'
  include 'profile::pupmod::travis_yml'
}
