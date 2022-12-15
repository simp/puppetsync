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

def file_info_string(file)
  out = file.to_s
  if File.symlink?(file)
    require 'pathname'
    p = Pathname.new(file)
    link_path = p.realpath.relative_path_from(Rake.application.original_dir)
    out = "#{out} -> #{link_path}"
  end
  out
end

def config_file(name)
  "data/sync/configs/#{name}.yaml"
end

def repolist_file(name)
  "data/sync/repolists/#{name}.yaml"
end


namespace :data do
  task :files, [:config,:repolist,:verbose] do |t,args|
    args.with_defaults(:config => 'latest')
    args.with_defaults(:repolist => 'latest')
    args.with_defaults(:verbose => false)
    config_file = config_file(args.config)
    repolist_file = repolist_file(args.repolist)

    out = ''
    out += "# config:   #{file_info_string(config_file)}\n"
    out += "# repolist: #{file_info_string(repolist_file)}\n"
    puts out
  end

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
    out += "# config:   #{file_info_string(config_file)}\n"
    out += "# repolist: #{file_info_string(repolist_file)}\n"
    out += data.to_yaml
    puts out
  end

  namespace :config do
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
