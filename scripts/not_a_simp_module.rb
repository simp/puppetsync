require 'puppetsync/script_helpers.rb'
include Puppetsync::ScriptHelpers

_data = Facter.value(:module_metadata)
fail 'FAIL: MUST be a Puppet module! (no metadata.json)' unless _data
fail "FAIL: MUST be a `simp` module! (forge org: '#{_data['forge_org']}')" unless _data['forge_org'] == 'simp'
fail 'FAIL: MUST not be simp-compliance_markup!' if _data['name'] == 'simp-compliance_markup'
