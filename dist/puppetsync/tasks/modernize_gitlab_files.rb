#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'

def split_gitlab_file(file)
  project_root = File.dirname(file)
  warn "=== file: #{file}"
  content = File.read(file)
  content.gsub!(%r{pup_5_5_16|pup_5_5_10}, 'pup_5_5_17')
  content.gsub!(%r{pup5\.5\.16|pup5\.5\.10}, 'pup5.5.17')
  content.gsub!(%r{pup_6_latest}, 'pup_6')
  content.gsub!(%r{pup_5_latest}, 'pup_5')
  File.open(file, 'w') { |f| f.puts content }
end

require 'json'
stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

file = params['file'] || ARGV
raise('No .gitlab-ci.yml path given') unless file

warn "\n\n#{file}"
split_gitlab_file(file)
warn "FINIS: #{__FILE__}"
