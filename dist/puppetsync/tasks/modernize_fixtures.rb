#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'
require 'yaml'

require 'tempfile'
require 'tmpdir'

def tmp_bundle_rake_execs(repo_path, tasks)
  Dir.mktmpdir('tmp_bundle_rake_execs') do |tmp_dir|
    Dir.chdir repo_path
    gemfile_lock = false
    if File.exist?('Gemfile.lock')
      gemfile_lock = File.expand_path('Gemfile.lock', tmp_dir)
      FileUtils.cp File.join(repo_path, 'Gemfile.lock'), gemfile_lock
    end
    results = []
    require 'bundler'
    require 'rake'
    Bundler.with_unbundled_env do
      sh '/opt/puppetlabs/bolt/bin/bundle install &> /dev/null'
      tasks.each do |task|
        puts
        cmd = "/opt/puppetlabs/bolt/bin/bundle exec /opt/puppetlabs/bolt/bin/rake #{task}"
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
  end
end

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  file = params['filename']
else
  file = ARGF.filename
end

# Read content from  file
warn "file: '#{file}'"
raise('No .fixtures path given') unless file
content = YAML.load_file(file)

# Transform content
warn "\n== Modernizing .fixtures content"
original_content_str = content.to_s

# regexp_for_low_high_bounds = %r[\A(?<low_op>>=?) (?<low_ver>\d+.*) (?<high_op><=?) (?<high_ver>\d+.*)\Z]
#
if %r{^ *#}.match?(content.to_s)
  raise "FATAL OMG there was a comment in '#{file}', it might be important and we don't preserve those yet; check it out"
end

content_repos = content.dig('fixtures', 'repositories').map { |k, v|
  unless v.is_a?(String) || v.is_a?(Hash)
    raise "NO HANDLER: fixtures.yml 'repositories' key is not a String or Hash!:\n#{v.to_yaml}\n"
  end
  if v.is_a?(String) && v =~ %r{^http} && v !~ %r{\.git$}
    v = "#{v}.git"
  elsif v.is_a?(Hash) && v['repo'] && v['repo'] =~ %r{^http} && v['repo'] !~ %r{\.git$}
    v['repo'] = "#{v['repo']}.git"
  end

  [k, v]
}.to_h

unless content_repos.nil? || content_repos.empty?
  content['fixtures']['repositories'] = content_repos
end

# Write content back to original file
File.open(file, 'w') { |f| f.puts content.to_yaml }

if content.to_s == original_content_str
  warn '  == content unchanged'
else
  warn '  ++ content was changed!'
  repo_path = File.dirname file
  tmp_bundle_rake_execs(repo_path, ['spec_prep', 'spec_clean'])
end

# Validate that the file is still valid YAML
warn "\n== Running a test YAML load #{file} to validate its syntax"
YAML.load_file file
warn "  ++ Test load (YAML syntax) on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
