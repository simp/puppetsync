#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'

def modernize_gitlab_ci(content)
  content.gsub!(%r{pup_5_5_16|pup_5_5_10}, 'pup_5_5_17')
  content.gsub!(%r{pup5\.5\.16|pup5\.5\.10}, 'pup5.5.17')
  content.gsub!(%r{pup_6_latest}, 'pup_6')
  content.gsub!(%r{pup_5_latest}, 'pup_5')

  # If there are no jobs for the new LTS, copy + gsub all the old LTS jobs
  if content.scan( /^(pup6\.16\.10(?!-unit|-lint)[-a-z0-9]*):\s*$/m ).empty?
    # Tested at: https://rubular.com/r/fuMdr0HDU1cqLd
    old_lts_jobs = content.scan( /^(pup5\.5\.17(?!-unit|-lint)[-a-z0-9]*:.*?(?=\Z|^#|^pup))/m ).flatten
    new_lts_jobs = old_lts_jobs.map{|x| x.gsub('pup_5_5_17','pup_6_16_0').gsub('pup5.5.17','pup6.16.0') }
    new_content = "#{content}\n#{new_lts_jobs.join}"
    return new_content unless new_lts_jobs.empty?
    content
  end
end

if ARGF.filename == '-'
  stdin = ''
  puts "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  require 'json'
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  file = params['file']
else
  file = ARGF.filename
end

warn "file: '#{file}'"
content = File.read(file)

raise('No .gitlab-ci.yml path given') unless file

warn "\n== Modernizing Gitlab CI content"
original_content = content.dup
content = modernize_gitlab_ci(original_content)
warn (content == original_content ? '  == content unchanged' : '  ++ content was changed!')

File.open(file, 'w') { |f| f.puts content.strip }

warn "\n== Running a test YAML.load_file on #{file} to validate its syntax"

require 'yaml'
YAML.load_file(file)
warn "  ++ Test YAML.load_file on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
