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

task :default => :strings
