#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'

require 'tempfile'
require 'tmpdir'

BUNDLER_EXE = ENV['BUNDLER_EXE'] || '/opt/puppetlabs/bolt/bin/bundle'
RAKE_EXE = ENV['RAKE_EXE'] || '/opt/puppetlabs/bolt/bin/rake'
BUNDLE_PATH = ENV['BUNDLE_PATH'] || '../../.vendor/bundle'

def tmp_bundle_rake_execs(repo_path, tasks, save_rake_stdout: false)
  Dir.mktmpdir('tmp_bundle_rake_execs') do |tmp_dir|
    Dir.chdir repo_path
    gemfile_lock = false
    if File.exist?('Gemfile.lock')
      gemfile_lock = File.expand_path('Gemfile.lock', tmp_dir)
      FileUtils.cp File.join(repo_path, 'Gemfile.lock'), gemfile_lock
    end
    results = []
    rake_stdout_files = {}
    require 'bundler'
    require 'rake'
    Bundler.with_unbundled_env do
      # sh "#{BUNDLER_EXE} config path .vendor/bundle &> /dev/null"
      sh "#{BUNDLER_EXE} install --path '#{BUNDLE_PATH}'  &> /dev/null"
      tasks.each do |task|
        puts
        cmd = ">&2 #{BUNDLER_EXE} exec #{RAKE_EXE} #{task}  "
        if save_rake_stdout
          out_file = "_rake__stdout.#{task}"
          cmd += " > #{out_file}"
          rake_stdout_files[task] = out_file
        end
        results << sh(cmd)
      end
      if gemfile_lock
        FileUtils.cp gemfile_lock, File.join(repo_path, 'Gemfile.lock')
      else
        FileUtils.rm('Gemfile.lock')
      end
    end
    unless results.all? { |x| x }
      warn 'bad result'
    end
    return rake_stdout_files if save_rake_stdout
  end
end

# ARGF hack to allow use run the task directly as a ruby script while testing
metadata_json_path = false
if ARGF.filename == '-'
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  metadata_json_path = params['filename']
else
  metadata_json_path = ARGF.filename
end

# Read content from metadata.json metadata_json_path
warn "metadata_json_path: '#{metadata_json_path}'"
raise('No metadata.json path given') unless metadata_json_path
pupmod_metadata = JSON.parse File.read(metadata_json_path)
repo_path = File.dirname metadata_json_path

unless ENV['UPDATE_NON_SIMP_MODULES'] == 'yes'
  if !%r{\Asimp[-/]}.match?(pupmod_metadata['name'])
    warn("\n\n\n== WARNING: SKIPPING update of non-simp module (#{content['name']}) (force with `UPDATE_NON_SIMP_MODULES=yes`)\n\n\n")
  else
    tmp_bundle_rake_execs(repo_path, ['strings:generate:reference'])

    Dir.chdir(repo_path) do |_dir|
      raise 'ERROR: no file at REFERENCE.md' unless File.exist?('REFERENCE.md')
      sh 'git add REFERENCE.md'
      sh ">&2 git commit -m 'Update REFERENCE.md' || :"
    end
    exit 0
  end
end

warn "\n\nFINIS: #{__FILE__}"
