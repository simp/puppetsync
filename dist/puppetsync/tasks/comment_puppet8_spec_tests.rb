#!/opt/puppetlabs/bolt/bin/ruby
require 'fileutils'
require 'json'

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  file = params['file']
else
  file = ARGF.filename
end

# Returns the spot in the file that is no longer managed by puppet
def get_index(input_file, str)
  content = File.read(input_file)
  start_idx = nil
  content.lines.each_with_index do |line, idx|
    if %r{#{str}}.match?(line)
      start_idx = idx
      return start_idx
    end
  end
  warn('No index match')
  start_idx = 0
end

warn "file: '#{file}'"
start_index = get_index(file, '^# Repo-specific content') # rubocop:disable Lint/UselessAssignment
ci_file = File.readlines(file.to_s)

# Comments out oel sections
comment = false
ci_file.each_with_index do |line, _idx|
  if %r{(^pup8.*)}.match?(line)
    comment = true
  end
  if %r{(^\n)}.match?(line)
    comment = false
  end
  if comment == true
    line.prepend('#')
  end
end
File.open(file, 'w') { |out| out.puts ci_file }
