#!/opt/puppetlabs/bolt/bin/ruby
# frozen_string_literal: true

# Set the version_requirement of named entries in a module's
# metadata.json `requirements` (e.g. raising openvox to '< 10.0.0' when a
# new OpenVox major ships).
#
# Only entries the module already declares are rewritten: a module that
# requires `puppet` but not `openvox` is reported, not converted, since
# that is a separate migration. Only semantic changes are written
# (JSON.pretty_generate, matching update_metadata_deps), so an unchanged
# repo stays clean and bump_module_version skips it.

require 'json'

stdin = STDIN.read
params = JSON.parse(stdin)

repo_path = params['repo_path']
raise('No repo_path given') unless repo_path
wanted = params['requirements']
raise('No requirements given') unless wanted.is_a?(Hash) && !wanted.empty?

metadata_path = File.join(repo_path, 'metadata.json')
unless File.exist?(metadata_path)
  puts JSON.generate({ 'changed' => false, 'skip' => 'no metadata.json' })
  exit 0
end

metadata = JSON.parse(File.read(metadata_path))
requirements = metadata['requirements'] || []

updates = []
wanted.each do |name, version_requirement|
  requirements.each do |req|
    next unless req.is_a?(Hash) && req['name'] == name
    next if req['version_requirement'] == version_requirement

    updates << { 'name' => name, 'from' => req['version_requirement'], 'to' => version_requirement }
    req['version_requirement'] = version_requirement
  end
end

declared = requirements.map { |r| r['name'] if r.is_a?(Hash) }.compact
missing = wanted.keys - declared

changed = !updates.empty?
File.write(metadata_path, JSON.pretty_generate(metadata) + "\n") if changed

result = { 'changed' => changed, 'updates' => updates }
result['not_declared'] = missing unless missing.empty?
puts JSON.generate(result)
