# Just do Travis
class role::pupmod_travis_only {
  include 'profile::common'
  include 'profile::pupmod::travis_yml'
}
