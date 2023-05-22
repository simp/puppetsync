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

#Returns the spot in the file that is no longer managed by puppet
def get_index(input_file, str)
  content = File.read(input_file)
  start_idx = nil
  content.lines.each_with_index do | line,idx |
    if line =~ /#{str}/
      start_idx = idx
      return start_idx
    end
  end
  warn("No index match")
  start_idx = 0
end

#Roll puppet6 -> 7, 7 -> 8
warn "file: '#{file}'"
start_index = get_index(file, "^# Repo-specific content")
ci_file = File.readlines("#{file}")
ci_file.each_with_index do | line,idx |
  if idx >= start_index
    puts "searching line:#{idx} #{line}"
    line.sub!("pup7", "pup8")
    line.sub!("pup_7", "pup_8")
    line.sub!('pup6', 'pup7')
    line.sub!('pup_6', 'pup_7')
  end
end

File.open(file, "w") { |out| out.puts ci_file } 
