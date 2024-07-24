# See the following for reference:
# - http://docs.ruby-lang.org/en/2.5.0/Gem/RequestSet/GemDependencyAPI.html
# - http://docs.ruby-lang.org/en/2.5.0/Gem/RequestSet/GemDependencyAPI.html#method-i-group
# - http://docs.ruby-lang.org/en/2.5.0/Gem/RequestSet/GemDependencyAPI.html#method-i-platform
# - http://docs.ruby-lang.org/en/2.5.0/Gem.html#method-c-use_gemdeps
source 'https://rubygems.org'

def ruby3?
  @ruby3 ||= Gem::Requirement.create(['>= 3']).satisfied_by?(Gem::Version.new(RUBY_VERSION.dup))
end

gem 'octokit', '~> 4.18'
gem 'jira-ruby', '~> 2.0'
# gem 'puppet-debugger', '~> 0.17'
gem 'puppet-debugger', '~> 0.2'
gem 'bundler', ['~> 2.0'] + (ruby3? ? [] : ['<= 2.4.22'])
gem 'pry', '~> 0.13'
gem 'pry-remote'
gem 'terminal-table', '~> 1.8'
gem 'facter', '~> 4.0'
gem 'gitlab'
gem 'jsonlint'
gem 'puppet', ENV.fetch('PUPPET_VERSION', ruby3? ? '~> 8' : '~> 7')

group :syntax do
  gem 'puppet-syntax', '~> 4.1',                 require: false
  gem 'puppet-lint', '~> 4.2',                   require: false
  gem 'voxpupuli-puppet-lint-plugins', '~> 5.0', require: false
  gem 'metadata-json-lint', '~> 4.0',            require: false
  # gem 'yamllint',                              require: false
  gem 'rubocop', '~> 1.42',                      require: false
  gem 'rubocop-rspec', '~> 3.0',                 require: false
  gem 'rubocop-performance', '~> 1.19',          require: false
  gem 'rubocop-rake', '~> 0.6',                  require: false
end

group :development do
  gem 'puppet-strings', '~> 4.0',                require: false
end
