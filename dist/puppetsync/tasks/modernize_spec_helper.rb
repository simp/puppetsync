#!/opt/puppetlabs/bolt/bin/ruby

require 'json'

def deprecate_manifest_dir(content)
  content.gsub!(%r{^.*(\w+)\.(manifest_dir)\b.*$}, '\& if \1.respond_to?(:\2)')
end

def deprecate_trusted_server_facts(content)
  content.gsub!(%r{^.*(\w+)\.(trusted_server_facts)\b.*$}, '\& if \1.respond_to?(:\2)')
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

# Read contents of spec/spec_helper.rb
warn "file: '#{file}'"
raise 'No spec_helper.rb path given' unless file
content = File.read(file)

warn "\n== Updating for deprecated manifest_dir"
original_content_str = content.dup

# These methods mutate `content` and its contents by reference
# ------------------------------------------------------------------------------
deprecate_manifest_dir(content)
deprecate_trusted_server_facts(content)

# Write content back to original file
File.open(file, 'w') { |f| f.puts content }

if content == original_content_str
  warn '  == content unchanged'
else
  warn '  ++ content was changed!'
end

# Sanity check: Validate that the file is still valid Ruby
warn "\n== Running a syntax check on #{file} (current dir: #{Dir.pwd})"
require 'rbconfig'
raise "  ++ Syntax test on #{file} failed!" unless Kernel.system(RbConfig.ruby, '-c', file)
warn "  ++ Syntax test on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
