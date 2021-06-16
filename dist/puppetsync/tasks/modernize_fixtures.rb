#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'
require 'yaml'

require 'tempfile'
require 'tmpdir'

def bump_version(file)
  # Read content from .fixtures file
  warn "file: '#{file}'"
  raise('No .fixtures path given') unless file
  dir = File.dirname(file)
  content = File.read(file)
  data = JSON.parse(content)

  # bump y version
  parts = data['version'].split(/[\.-]/)
  parts[1] = (parts[1].to_i + 1).to_s
  parts[2] = '0'
  new_version = parts.join('.')
  data['version'] = new_version

  File.open(file,'w'){|f| f.puts(JSON.pretty_generate(data)) }
  warn "\n\n++ processed '#{file}'"

  if new_version
    changelog_file = File.join(dir,'CHANGELOG')
    changelog = File.read(changelog_file)
    require 'date'
    new_lines = []
    new_lines << DateTime.now.strftime("* %a %b %d %Y Chris Tessmer <chris.tessmer@onyxpoint.com> - #{new_version}")
    new_lines << '- Removed support for Puppet 5'
    new_lines << '- Ensured support for Puppet 7 in requirements and stdlib'
    changelog = new_lines.join("\n") + "\n\n" + changelog
    File.open(changelog_file,'w'){|f| f.puts changelog }
  end
end


def tmp_bundle_rake_execs(repo_path, tasks)
  Dir.mktmpdir('tmp_bundle_rake_execs') do |tmp_dir|
    Dir.chdir repo_path
    gemfile_lock = false
    if File.exist?('Gemfile.lock')
      gemfile_lock = File.expand_path('Gemfile.lock',tmp_dir)
      FileUtils.cp File.join(repo_path, 'Gemfile.lock'), gemfile_lock
    end
    results = []
    require 'bundler'
    require 'rake'
    Bundler.with_unbundled_env do
      sh "/opt/puppetlabs/bolt/bin/bundle install &> /dev/null"
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
    unless results.all?{ |x| x }
      warn 'bad result'
    end
  end
end


# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  stdin = ''
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
content = YAML.load File.read(file)

# Transform content
warn "\n== Modernizing .fixtures content"
original_content_str = content.to_s

#regexp_for_low_high_bounds = %r[\A(?<low_op>>=?) (?<low_ver>\d+.*) (?<high_op><=?) (?<high_ver>\d+.*)\Z]
#
content_repos = content.dig('fixtures','repositories').map do |k,v|
  fail "NO HANDLER: fixture repositories is not a String!:\n#{v.to_yaml}\n" unless v.is_a?(String)
  if v.is_a?(String) && v =~ /^http/ && v !~ /\.git$/
    v = "#{v}.git"
  elsif v.is_a?(Hash) && v['repo'] && v['repo'] =~ /^http/ && v['repo'] !~ /\.git$/
    v['repo'] = "#{v['repo']}.git"
  end

  [k,v]
end.to_h

unless content_repos.nil? or content_repos.empty?
  content['fixtures']['repositories'] = content_repos
end

#mdfile = File.join(File.dirname(file),'metadata.json')
#metadata = JSON.parse(File.read(mdfile))
#mod_name = metadata['name'].split('-').last
#
#unless content.dig('symlinks',mod_name)
#  content['symlinks'] ||= {}
#  content['symlinks'][mod_name] = '#{source_dir}'
#end

# Write content back to original file
File.open(file, 'w') { |f| f.puts content.to_yaml }

if content.to_s == original_content_str
  warn '  == content unchanged'
else
  warn '  ++ content was changed!'
  repo_path = File.dirname file
  #bump_version(file)
  tmp_bundle_rake_execs(repo_path, ['spec_prep', 'spec_clean'])
end

# Sanity check: Validate that the file is still valid YAML
warn "\n== Running a test YAML load #{file} to validate its syntax"
YAML.load_file file
warn "  ++ Test load (YAML syntax) on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
