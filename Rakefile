desc <<~DESC
  Generate REFERENCE.md for puppetsync

  (TODO: after breaking puppetsync into its own module, document roles & profiles)
DESC

task :strings do
  sh '/opt/puppetlabs/bolt/bin/puppet strings generate --format markdown'
end
