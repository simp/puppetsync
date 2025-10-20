#!/usr/bin/env ruby

require 'json'

stdin = $stdin.read
params = JSON.parse(stdin)

Dir.chdir(params['path'])

unless File.exist?('renovate.json') || File.exist?('renovate.json5')
  raise 'No support for JSON5 renovate configuration' if File.exist?('renovate.json5')

  warn 'No renovate configuration found'
  exit 0
end

config = JSON.parse(File.read('renovate.json'))

config['extends'] ||= []
config['extends'] |= [
  'config:recommended',
  'github>simp/renovate-config',
  'github>simp/renovate-config:ruby.json',
]

File.write('renovate.json', "#{JSON.pretty_generate(config)}\n")

# Update Gemfile to configure regex custom manager
if File.exist?('Gemfile')
  gemfile = File.read('Gemfile').lines
  renovate_comment = '# renovate: datasource=rubygems versioning=ruby'

  updated_gemfile = gemfile.map.with_index do |line, index|
    last_line = index.positive? ? gemfile[index - 1] : nil
    line = if (m = %r{^(\s*)gem\b.*\bENV\b}.match(line)) && !last_line&.include?(renovate_comment)
             "#{m[1]}#{renovate_comment}\n#{line}"
           else
             line.dup
           end

    # Update simp-rake-helpers dependency to ~> 5.24.0
    line.sub!(%r{(?<![,|]\s\[)(['"])(?:~>|>=)\s*\d+(?:\.\d+){0,2}\1}, "'~> 5.24.0'") if line.include?('simp-rake-helpers')

    # Update simp-rspec-puppet-facts dependency to ~> 4.0.0
    line.sub!(%r{(?<![,|]\s\[)(['"])~>\s*[0-3](?:\.\d+){0,2}\1}, "'~> 4.0.0'") if line.include?('simp-rspec-puppet-facts')

    line
  end

  File.write('Gemfile', updated_gemfile.join)
end
