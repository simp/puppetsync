ENV.fetch('GEM_SERVERS','https://rubygems.org')
  .split(/[, ]+/)
  .each{ |gem_source| source gem_source }

# activesupport 5.0+ requires ruby 2.2.2+
gem 'activesupport', '~> 4.0'

gem 'puppet',     ENV.fetch('PUPPET_VERSION', '~> 6.0')
# gem 'puppetsync', ENV.fetch('PUPPETSYNC_VERSION', '~> 0.1.0')
gem 'puppetsync',  :git => 'git@gitlab.com:chris.tessmer/puppetsync.git', :branch => 'new_gem'

#gem 'bolt', '~> 2.0'
gem 'rake'


gem 'pry'
gem 'pry-coolline'
