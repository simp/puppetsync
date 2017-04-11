ENV.fetch('GEM_SERVERS','https://rubygems.org')
  .split(/[, ]+/)
  .each{ |gem_source| source gem_source }

# activesupport 5.0+ requires ruby 2.2.2+
gem 'activesupport', '~> 4.0'

gem 'puppet',     ENV.fetch('PUPPET_VERSION', '~> 4.0')
gem 'puppetsync', ENV.fetch('PUPPETSYNC_VERSION', '~> 0.1.0')


gem 'pry'
gem 'pry-coolline'
