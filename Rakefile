#!/opt/puppetlabs/bolt/bin/rake -f
require 'rake/clean'

desc <<~DESC
  Generate REFERENCE.md for puppetsync

  (TODO: after breaking puppetsync into its own module, document roles & profiles)
DESC

task :strings, [:verbose] do |t,args|
  args.with_defaults(:verbose => false)
  sh %Q[/opt/puppetlabs/bolt/bin/puppet strings generate \
     #{args.verbose ? ' --verbose' : '' } --format markdown \
     "{dist,site-modules}/**/*.{pp,rb,json}"].gsub(/ {3,}/,' ')
end

namespace :install do
  desc "Install gems into #{__dir__}/.gems"
  task :gems do
    Dir.chdir __dir__
    sh %Q[GEM_HOME=.gems /opt/puppetlabs/bolt/bin/gem install -g gem.deps.rb --no-document]
  end

  desc "Install modules from Puppetfile into #{__dir__}}/modules"
  task :puppetfile do
    Dir.chdir __dir__
    sh %Q[GEM_HOME=.gems /opt/puppetlabs/bolt/bin/bolt puppetfile install]
  end
end


desc 'Install prereqs'
task :install => ['install:gems', 'install:puppetfile']

CLEAN.include( Dir['????????-????-????-????-????????????'].reject{|x| x.strip !~ /^[\h-]{36}$/ } )
CLEAN.include( Dir['puppetsync__sync.*.????????_???????.*'] ).select{|x| x.strip =~ /\.(yaml|txt)$/ }

task :default => :strings
