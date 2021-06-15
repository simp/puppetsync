#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'

def modernize_gitlab_ci(content)
  content.gsub!(%r[\n\n^pup5.*?(?=\n\n)]m,'')   # Remove pup5 blocks (nice formatting)
  content.gsub!(%r[^pup5.*?(?=\n\n)]m,'')   # Remove pup5 blocks that beign with comments

  content.gsub!(%r{pup6\.(?:16|17|18)\.0}, 'pup6.22.1')
  content.gsub!(%r{pup_6_(?:16|17|18)_0}, 'pup_6_22_1')
  content.gsub!(%r{pup_6_latest}, 'pup_6')

  content.gsub!(%r{only_with_SIMP_FULL_MATRIX}, 'with_SIMP_ACCEPTANCE_MATRIX_LEVEL_3')

  # convert latest pup anchors to format 'pup_<maj>_x'
  content.gsub!(%r{\bpup_(?<maj>[67])\b}, 'pup_\\k<maj>_x')
  content.gsub!(%r{\bpup(?<maj>[67])(?<char>-|:)}, 'pup\\k<maj>.x\\k<char>')

  # convert pinned pup anchors to format 'pup_<maj>'
  # (...which used to be the format for latest)
  content.gsub!(%r{\bpup6\.22\.1},   'pup6.pe')
  content.gsub!(%r{\bpup_6_22_1\b},  'pup_6_pe')

  content.gsub!(%r{bundle exec rake beaker:suites'},"bundle exec rake beaker:suites[default,default]'")
  content
end

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  stdin = ''
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  require 'json'
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  file = params['file']
else
  file = ARGF.filename
end

# Read content from .gitlab-ci.yml file
warn "file: '#{file}'"
raise('No .gitlab-ci.yml path given') unless file
content = File.read(file)

# Transform content
warn "\n== Modernizing Gitlab CI content"
original_content = content.dup
content = modernize_gitlab_ci(original_content)
warn (content == original_content ? '  == content unchanged' : '  ++ content was changed!')

# Write content back to original file
File.open(file, 'w') { |f| f.puts content.strip }

# Sanity check: Validate that the file is still valid YAML
# NOTE: Handle heavier, gitlab/domain-aware lint checks in other tasks
warn "\n== Running a test YAML.load_file on #{file} to validate its syntax"
require 'yaml'
YAML.load_file(file)
warn "  ++ Test YAML.load_file on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
