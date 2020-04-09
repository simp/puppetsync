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


desc "Install gems into #{__dir__}/.gems"
task :install_gems do |t,args|
  Dir.chdir __dir__
  sh %Q[GEM_HOME=.gems /opt/puppetlabs/bolt/bin/gem install -g gem.deps.rb --no-document]
end

CLEAN.include( Dir['????????-????-????-????-????????????'].reject{|x| x.strip !~ /^[\h-]{36}$/ } )

task :default => :strings

