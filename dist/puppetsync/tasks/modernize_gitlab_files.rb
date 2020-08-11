#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'

def modernize_gitlab_ci(content)
  content.gsub!(%r{pup_5_5_(?:10|16|17)}, 'pup_5_5_20')
  content.gsub!(%r{pup5\.5\.(?:10|16|17)}, 'pup5.5.20')
  content.gsub!(%r{pup_6_latest}, 'pup_6')
  content.gsub!(%r{pup_5_latest}, 'pup_5')

  content.gsub!(%r{only_with_SIMP_FULL_MATRIX}, 'with_SIMP_ACCEPTANCE_MATRIX_LEVEL_3')

  # Idempotently copy new jobs for the new PE2019.8 LTS (from the old LTS)
  if content.scan( /^(pup6\.16\.0(?!-unit|-lint)[-a-z0-9]*):\s*$/m ).empty?
    # Regex test at https://rubular.com/r/fuMdr0HDU1cqLd
    old_lts_jobs = content.scan( /^(pup5\.5\.17(?!-unit|-lint)[-a-z0-9]*:.*?(?=\Z|^#|^pup))/m ).flatten
    new_lts_jobs = old_lts_jobs.map{|x| x.gsub('pup_5_5_17','pup_6_16_0').gsub('pup5.5.17','pup6.16.0') }
    new_content = "#{content}\n#{new_lts_jobs.join}"
    return new_content unless new_lts_jobs.empty?
  end
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
