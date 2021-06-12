#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'




require 'tempfile'
require 'bundler'
require 'rake'
require 'tmpdir'

require 'fileutils'


def bump_version(file)
  # Read content from metadata.json file
  warn "file: '#{file}'"
  raise('No metadata.json path given') unless file
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
  Dir.mktmpdir do |tmp_dir|
    gemfile = File.expand_path('Gemfile',tmp_dir)
    FileUtils.cp File.join(repo_path, 'Gemfile'), gemfile
    Dir.chdir repo_path
    results = []
    Bundler.with_unbundled_env do
      sh "/opt/puppetlabs/bolt/bin/bundle --gemfile '#{gemfile}' &> /dev/null"
      tasks.each do |task|
        puts
        results << sh( "/opt/puppetlabs/bolt/bin/bundle exec /opt/puppetlabs/bolt/bin/rake #{task}")
      end
    end
    if results.all?{ |x| x } ###$CHILD_STATUS.success?
      puts "== #{File.basename(repo_path)} : committed changes in #{repo_path}"
    else
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
  file = params['file']
else
  file = ARGF.filename
end

# Read content from metadata.json file
warn "file: '#{file}'"
raise('No metadata.json path given') unless file
content = JSON.parse File.read(file)

# Transform content
warn "\n== Modernizing metadata.json content"
original_content_str = content.to_s

#regexp_for_low_high_bounds = %r[\A(?<low_op>>=?) (?<low_ver>\d+.*) (?<high_op><=?) (?<high_ver>\d+.*)\Z]

content['requirements'].select{|x| x['name'] == 'puppet' }.map do |x|
  #x['version_requirement'].gsub!( regexp_for_low_high_bounds ) do |y|
  #  m = Regexp.last_match
  #  "#{m[:low_op} #{m[:low_ver]} >= 6.18.0 < 8.0.0"
  #end
  x['version_requirement'] = '>= 6.18.0 < 8.0.0'
end

content['dependencies'].select{|x| x['name'] == 'puppetlabs/stdlib' }.map do |x|
  x['version_requirement'] = '>= 6.18.0 < 8.0.0'
end

# Write content back to original file
File.open(file, 'w') { |f| f.puts JSON.pretty_generate(content) }

if content.to_s == original_content_str
  warn '  == content unchanged'
else
  warn '  ++ content was changed!'
  repo_path = File.dirname file
  bump_version(file)
  tmp_bundle_rake_execs(repo_path, ['pkg:check_version', 'pkg:compare_latest_tag'])
end


# Sanity check: Validate that the file is still valid JSON
# NOTE: Handle heavier, gitlab/domain-aware lint checks in other tasks
warn "\n== Running a test json load #{file} to validate its syntax"
require 'json'
JSON.parse File.read(file)
warn "  ++ Test load (JSON syntax)  on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
