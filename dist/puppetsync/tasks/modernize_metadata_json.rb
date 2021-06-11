#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'

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
original_content = content.dup

#regexp_for_low_high_bounds = %r[\A(?<low_op>>=?) (?<low_ver>\d+.*) (?<high_op><=?) (?<high_ver>\d+.*)\Z]

content['requirements'].select{|x| x['name'] == 'puppet' }.map do |x|
  #x['version_requirement'].gsub!( regexp_for_low_high_bounds ) do |y|
  #  m = Regexp.last_match
  #  ">= 6.0.0 < 8.0.0"
  #end
  x['version_requirement'] = '>= 6.0.0 < 8.0.0'
end

content['dependencies'].select{|x| x['name'] == 'puppetlabs/stdlib' }.map do |x|
  #x['version_requirement'].gsub!( regexp_for_low_high_bounds ) do |y|
  #  m = Regexp.last_match
  #  ">= 6.0.0 < 8.0.0"
  #end
  x['version_requirement'] = '>= 6.0.0 < 8.0.0'
end

warn (content == original_content ? '  == content unchanged' : '  ++ content was changed!')

# Write content back to original file
File.open(file, 'w') { |f| f.puts JSON.pretty_generate(content) }

# Sanity check: Validate that the file is still valid YAML
# NOTE: Handle heavier, gitlab/domain-aware lint checks in other tasks
warn "\n== Running a test json load #{file} to validate its syntax"
require 'json'
JSON.parse File.read(file)
warn "  ++ Test load (JSON syntax)  on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
