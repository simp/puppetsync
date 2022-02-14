#!/opt/puppetlabs/bolt/bin/rake -f
require 'rake/clean'

BOLT_BIN_PATH="/opt/puppetlabs/bolt/bin"
BOLT_GEM_EXE=File.join(BOLT_BIN_PATH,'gem')
BOLT_PUPPET_EXE=File.join(BOLT_BIN_PATH,'puppet')
BOLT_EXE=File.join(BOLT_BIN_PATH,'bolt')
GEM_HOME='.gems'

CLEAN.include( Dir['????????-????-????-????-????????????'].reject{|x| x.strip !~ /^[\h-]{36}$/ } )
CLEAN.include( [GEM_HOME, 'tmpdir', 'gem.deps.rb.lock'] )
CLOBBER << '_repos'

desc <<~DESC
  Generate REFERENCE.md for puppetsync

  (TODO: after breaking puppetsync into its own module, document roles & profiles)
DESC

namespace :data do
  task :repolist, [:config,:repolist,:verbose] do |t,args|
    args.with_defaults(:config => 'latest')
    args.with_defaults(:repolist => 'latest')
    args.with_defaults(:verbose => false)
    cmd = %Q[#{BOLT_EXE} lookup --plan-hierarchy puppetsync::repos_config \
      config="#{args.config}" \
      repolist="#{args.repolist}" \
      batchlist="" \
      --log-level "#{args.verbose ? 'debug' : 'info'}" \
      --format json
    ].gsub(/ +/, ' ')
    stdout = %x[#{cmd}]
    require 'json'
    data = JSON.parse(stdout)
    require 'yaml'
    config_file = "data/sync/configs/#{args.config}.yaml"
    repolist_file = "data/sync/repolists/#{args.repolist}.yaml"
    out = ''
    out += "# config:   #{config_file}#{ File.symlink?(config_file) ? " -> #{File.readlink(config_file)}" : ''}\n"
    out += "# repolist: #{repolist_file}#{ File.symlink?(repolist_file) ? " -> #{File.readlink(repolist_file)}" : ''}\n"
    out += data.to_yaml
    puts out
  end
end
task :strings, [:verbose] do |t,args|
  args.with_defaults(:verbose => false)
  sh %Q[#{BOLT_PUPPET_EXE} strings generate \
     #{args.verbose ? ' --verbose' : '' } --format markdown \
     "{dist,modules}/**/*.{pp,rb,json}"].gsub(/ {3,}/,' ')
end

namespace :install do
  desc "Install gems into #{__dir__}/.gems"
  task :gems do
    Dir.chdir __dir__
    sh %Q[GEM_HOME="#{GEM_HOME}" "#{BOLT_GEM_EXE}" install -g gem.deps.rb --no-document --no-user-install]
    sh %Q[ls -lart]
  end

  desc "Install Puppet modules from bolt-project.yaml into #{__dir__}/.modules"
  task :modules do
    Dir.chdir __dir__
    sh %Q[GEM_HOME="#{GEM_HOME}" "#{BOLT_EXE}" module install --force]
  end
end

namespace :list do
  desc "Installed gems (pass in true to list only project gems)"
  task :gems, :project_only do |t,args|
    args.with_defaults(:project_only => false)
    Dir.chdir __dir__
    cmd =%Q[GEM_HOME="#{GEM_HOME}" "#{BOLT_GEM_EXE}" list]
    cmd ="GEM_PATH= #{cmd}" if args.project_only
    sh cmd
  end
end

desc 'Install prereqs (RubyGems and Puppet modules)'
task :install => ['install:gems', 'install:modules']

task :default => :install
