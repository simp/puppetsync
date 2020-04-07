# Manage ONLY .travis.yml in Puppet modules
class role::pupmod_travis_only {
  # include 'profile::common' # <-- don't even include common functions
  include 'profile::pupmod::travis_yml'
}
