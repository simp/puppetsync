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
  gemfile = File.read('Gemfile').lines(chomp: true)
  renovate_comment = '# renovate: datasource=rubygems versioning=ruby'

  updated_gemfile = gemfile.map.with_index do |line, index|
    # Workarounds for test failures due to outdated dependencies
    case line
    when %r{^\s*gem\s+(['"])simp-beaker-helpers\1}
      # Update simp-beaker-helpers dependency to ~> 2.0.0
      line.sub!(%r{^(\s*gem\s).*$}, "\\1'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 2.0.0')")
    when %r{^\s*gem\s+(['"])simp-rake-helpers\1}
      # Update simp-rake-helpers dependency to ~> 5.24.0
      line.sub!(%r{^(\s*gem\s).*$}, "\\1'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 5.24.0')")
    when %r{\bsimp-rspec-puppet-facts\b}
      # Update simp-rspec-puppet-facts dependency to ~> 4.0.0
      line.sub!(%r{(?<![,|]\s\[)(['"])~>\s*[0-3](?:\.\d+){0,2}\1}, "'~> 4.0.0'")
    when %r{\bpuppetlabs_spec_helper\b}
      # Pin puppetlabs_spec_helper to ~> 8.0.0
      line.sub!(%r{(?<![,|]\s\[)(['"])~>\s*[0-7](?:\.\d+){0,2}\1}, "'~> 8.0.0'")
      line << ", '~> 8.0.0'" if %r{^\s*gem\s+(['"])puppetlabs_spec_helper\1$}.match?(line)
    end

    last_line = index.positive? ? gemfile[index - 1] : nil
    line = if (m = %r{^(\s*)gem\b.*\bENV\b}.match(line)) && !last_line&.include?(renovate_comment)
             "#{m[1]}#{renovate_comment}\n#{line}"
           else
             line.dup
           end

    line
  end

  File.write('Gemfile', "#{updated_gemfile.join("\n")}\n")
end
