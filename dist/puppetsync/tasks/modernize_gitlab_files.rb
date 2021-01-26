#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'

def modernize_gitlab_ci(content)
  content.gsub!(%r{pup_5_5_(?:10|16|17)}, 'pup_5_5_20')
  content.gsub!(%r{pup5\.5\.(?:10|16|17)}, 'pup5.5.20')
  content.gsub!(%r{pup6\.(?:16|17)\.0}, 'pup6.18.0')
  content.gsub!(%r{pup_6_(?:16|17)_0}, 'pup_6_18_0')
  content.gsub!(%r{pup_6_latest}, 'pup_6')
  content.gsub!(%r{pup_5_latest}, 'pup_5')

  content.gsub!(%r{only_with_SIMP_FULL_MATRIX}, 'with_SIMP_ACCEPTANCE_MATRIX_LEVEL_3')

  # Idempotently copy new jobs for the new PE2019.8 LTS (from the old LTS)
  if content.scan( /^(pup6\.18\.0(?!-unit|-lint)[-a-z0-9]*):\s*$/m ).empty?
    # Regex test at https://rubular.com/r/fuMdr0HDU1cqLd
    old_lts_jobs = content.scan( /^(pup5\.5\.17(?!-unit|-lint)[-a-z0-9]*:.*?(?=\Z|^#|^pup))/m ).flatten
    new_lts_jobs = old_lts_jobs.map{|x| x.gsub('pup_5_5_17','pup_5_5.20').gsub('pup5.5.17','pup5.5.20') }
    new_lts_jobs = old_lts_jobs.map{|x| x.gsub('pup_6_16_0','pup_6_18_0').gsub('pup6.16.0','pup6.18.0') }
    new_content = "#{content}\n#{new_lts_jobs.join}"
    return new_content unless new_lts_jobs.empty?
  end

  # convert latest pup anchors to format 'pup_<maj>_x'
  content.gsub!(%r{\bpup_([567])\b}, 'pup_\\1_x')
  content.gsub!(%r{\bpup([567])(-|:)}, 'pup\\1.x\\2')

  # convert pinned pup anchors to format 'pup_<maj>'
  # (...which used to be the format for latest)
  content.gsub!(%r{\bpup6\.18\.0}, 'pup6.pe')
  content.gsub!(%r{\bpup5\.5\.\d+}, 'pup5.pe')
  content.gsub!(%r{\bpup_6_18_0\b}, 'pup_6_pe')
  content.gsub!(%r{\bpup_5_5_\d+\b}, 'pup_5_pe')
  content.gsub!(%r{\bpup_5_5_\d+\b}, 'pup_5_pe')

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
