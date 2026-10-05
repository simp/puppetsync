require 'spec_helper'

describe 'task: update_metadata_requirements' do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @repo = dir
      example.run
    end
  end

  def write_metadata(requirements)
    File.write(File.join(@repo, 'metadata.json'), JSON.pretty_generate(
      'name' => 'simp-fixture', 'version' => '1.2.3', 'dependencies' => [],
      'requirements' => requirements,
    ) + "\n")
  end

  def metadata
    JSON.parse(File.read(File.join(@repo, 'metadata.json')))
  end

  def run_update(requirements = { 'openvox' => '>= 8.0.0 < 10.0.0' })
    out, err, status = run_task('update_metadata_requirements.rb', 'repo_path' => @repo, 'requirements' => requirements)
    raise "task failed: #{err}" unless status.success?

    JSON.parse(out)
  end

  it 'rewrites a declared requirement' do
    write_metadata([{ 'name' => 'openvox', 'version_requirement' => '>= 8.0.0 < 9.0.0' }])
    result = run_update
    expect(result['changed']).to be true
    expect(result['updates']).to eq([{ 'name' => 'openvox', 'from' => '>= 8.0.0 < 9.0.0', 'to' => '>= 8.0.0 < 10.0.0' }])
    expect(metadata['requirements']).to eq([{ 'name' => 'openvox', 'version_requirement' => '>= 8.0.0 < 10.0.0' }])
  end

  it 'leaves an already-current requirement byte-for-byte untouched' do
    write_metadata([{ 'name' => 'openvox', 'version_requirement' => '>= 8.0.0 < 10.0.0' }])
    before = File.read(File.join(@repo, 'metadata.json'))
    result = run_update
    expect(result['changed']).to be false
    expect(File.read(File.join(@repo, 'metadata.json'))).to eq(before)
  end

  it 'does not add a requirement the module does not declare, and reports it' do
    write_metadata([{ 'name' => 'puppet', 'version_requirement' => '>= 7.0.0 < 9.0.0' }])
    result = run_update
    expect(result['changed']).to be false
    expect(result['not_declared']).to eq(['openvox'])
    expect(metadata['requirements']).to eq([{ 'name' => 'puppet', 'version_requirement' => '>= 7.0.0 < 9.0.0' }])
  end

  it 'leaves other requirements alone' do
    write_metadata([
      { 'name' => 'puppet', 'version_requirement' => '>= 7.0.0 < 9.0.0' },
      { 'name' => 'openvox', 'version_requirement' => '>= 8.0.0 < 9.0.0' },
    ])
    run_update
    expect(metadata['requirements'][0]).to eq('name' => 'puppet', 'version_requirement' => '>= 7.0.0 < 9.0.0')
    expect(metadata['requirements'][1]['version_requirement']).to eq('>= 8.0.0 < 10.0.0')
  end

  it 'skips a repo without metadata.json' do
    expect(run_update).to include('changed' => false, 'skip' => 'no metadata.json')
  end
end
