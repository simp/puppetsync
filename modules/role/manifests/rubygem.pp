# Manage RubyGem
class role::rubygem {
  include 'profile::base'
  include 'profile::obsoletes'
  include 'profile::github_actions'
}
