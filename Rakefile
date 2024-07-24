#!/opt/puppetlabs/bolt/bin/rake -f
require 'rake/clean'
require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet-strings/tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'metadata-json-lint/rake_task'
require 'rubocop/rake_task'

begin
  require 'yaml'
  exclude_paths = YAML.safe_load(File.read('.rubocop.yml')).dig('AllCops', 'Exclude')
rescue StandardError => e
  warn "Failed to load path exclusions: #{e.message}"
end

PuppetSyntax.exclude_paths = exclude_paths unless exclude_paths.nil?
PuppetSyntax.check_hiera_keys = true

PuppetLint::RakeTask.new :lint do |config|
  config.ignore_paths = exclude_paths unless exclude_paths.nil?
end

RuboCop::RakeTask.new do |task|
  task.requires << 'rubocop-rake'
end

BOLT_BIN_PATH = '/opt/puppetlabs/bolt/bin'.freeze
BOLT_GEM_EXE = File.join(BOLT_BIN_PATH, 'gem')
BOLT_PUPPET_EXE = File.join(BOLT_BIN_PATH, 'puppet')
BOLT_EXE = File.join(BOLT_BIN_PATH, 'bolt')
GEM_HOME = '.gems'.freeze

CLEAN.include(Dir['????????-????-????-????-????????????'].select { |x| x.strip =~ %r{^[\h-]{36}$} })
CLEAN.include([GEM_HOME, 'tmpdir', 'gem.deps.rb.lock'])
CLOBBER << '_repos'

@target_name_max_length = 40

def file_info_string(file)
  out = file.to_s
  if File.symlink?(file)
    require 'pathname'
    p = Pathname.new(file)
    target_missing = p.exist? ? false : true
    if File.symlink?(file)
      link_path = if target_missing
                    p.readlink
                  else
                    p.realpath.relative_path_from(Rake.application.original_dir)
                  end
      out = "#{out.rjust(@target_name_max_length + 1)} -> #{link_path}"
    else
      out = "#{out.rjust(@target_name_max_length + 1)}    !!! FILE !!!"
    end
    out += '  !!! MISSING !!!' if target_missing
  end
  out
end

def config_file(name)
  "data/sync/configs/#{name}.yaml"
end

def repolist_file(name)
  "data/sync/repolists/#{name}.yaml"
end

def display_config_paths(config_file:, repolist_file:)
  @target_name_max_length = [config_file, repolist_file].map(&:size).max

  out = ''
  out += "# config:   #{file_info_string(config_file)}\n"
  out += "# repolist: #{file_info_string(repolist_file)}\n"
  puts out

  exit 1 if out.include?('MISSING')
end

namespace :data do
  desc "Display puppetsync's latest config paths"
  task :files, [:config, :repolist, :verbose] do |_t, args|
    args.with_defaults(config: 'latest')
    args.with_defaults(repolist: 'latest')
    args.with_defaults(verbose: false)
    display_config_paths(
      config_file: config_file(args.config),
      repolist_file: repolist_file(args.repolist),
    )
  end

  desc 'Display puppetsync repo config'
  task :repolist, [:config, :repolist, :verbose] do |_t, args|
    args.with_defaults(config: 'latest')
    args.with_defaults(repolist: 'latest')
    args.with_defaults(verbose: false)
    cmd = %(#{BOLT_EXE} lookup --plan-hierarchy puppetsync::repos_config \
      config="#{args.config}" \
      repolist="#{args.repolist}" \
      batchlist="" \
      --log-level "#{args.verbose ? 'debug' : 'info'}" \
      --format json
    ).squeeze(' ')
    stdout = `#{cmd}`
    require 'json'
    data = JSON.parse(stdout) # rubocop:disable Lint/UselessAssignment
    require 'yaml'
    config_file = "data/sync/configs/#{args.config}.yaml" # rubocop:disable Lint/UselessAssignment
    repolist_file = "data/sync/repolists/#{args.repolist}.yaml" # rubocop:disable Lint/UselessAssignment
    display_config_paths(
      config_file: config_file(args.config),
      repolist_file: repolist_file(args.repolist),
    )
  end

  namespace :config do
  end
end

desc <<~DESC
Generate latest config REFERENCE.md for puppetsync

  (TODO: after breaking puppetsync into its own module, document role & profile classes)
DESC
task :strings, [:verbose] do |_t, args|
  args.with_defaults(verbose: false)
  sh %(#{BOLT_PUPPET_EXE} strings generate \
     #{args.verbose ? ' --verbose' : ''} --format markdown \
     "{dist,modules}/**/*.{pp,rb,json}").gsub(%r{ {3,}}, ' ')
end

namespace :install do
  desc "Install gems into #{__dir__}/.gems"
  task :gems do
    Dir.chdir __dir__
    sh %(GEM_HOME="#{GEM_HOME}" "#{BOLT_GEM_EXE}" install -g gem.deps.rb --no-document --no-user-install)
    sh %(ls -lart)
  end

  desc "Install Puppet modules from bolt-project.yaml into #{__dir__}/.modules"
  task :modules do
    Dir.chdir __dir__
    sh %(GEM_HOME="#{GEM_HOME}" "#{BOLT_EXE}" module install --force)
  end
end

namespace :list do
  desc 'Installed gems (pass in true to list only project gems)'
  task :gems, :project_only do |_t, args|
    args.with_defaults(project_only: false)
    Dir.chdir __dir__
    cmd = %(GEM_HOME="#{GEM_HOME}" "#{BOLT_GEM_EXE}" list)
    cmd = "GEM_PATH= #{cmd}" if args.project_only
    sh cmd
  end
end

desc 'Install prereqs (RubyGems and Puppet modules)'
task install: ['install:gems', 'install:modules']

task default: :install
