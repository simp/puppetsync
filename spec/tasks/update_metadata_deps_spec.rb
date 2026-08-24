require 'spec_helper'
require 'socket'

# A minimal single-threaded HTTP responder serving canned Forge API
# responses (webrick is no longer stdlib, so plain sockets it is). Counts
# requests so specs can assert the one-lookup-per-slug guarantee.
class FakeForge
  attr_reader :requests

  def initialize(modules)
    @modules = modules
    @requests = []
    @server = TCPServer.new('127.0.0.1', 0)
    @thread = Thread.new { loop { serve(@server.accept) } }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}/v3"
  end

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve(sock)
    request_line = sock.gets
    nil while sock.gets&.strip&.length&.positive? # drain headers
    path = request_line.split(' ')[1]
    slug = path[%r{/v3/modules/([^/?]+)}, 1]
    @requests << slug
    if @modules.key?(slug)
      body = JSON.generate(@modules[slug])
      sock.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
    else
      sock.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    end
  ensure
    sock.close
  end
end

describe 'task: update_metadata_deps' do
  FORGE_MODULES = {
    # current release inside typical ranges
    'puppetlabs-stdlib' => { 'slug' => 'puppetlabs-stdlib', 'current_release' => { 'version' => '9.6.0' } },
    # current release beyond typical upper bounds
    'puppet-systemd' => { 'slug' => 'puppet-systemd', 'current_release' => { 'version' => '8.1.0' } },
    # a supersede chain: old -> mid -> new
    'herculesteam-augeasproviders_grub' => {
      'slug' => 'herculesteam-augeasproviders_grub',
      'superseded_by' => { 'slug' => 'puppet-augeasproviders_grub' },
    },
    'puppet-augeasproviders_grub' => { 'slug' => 'puppet-augeasproviders_grub', 'current_release' => { 'version' => '5.3.1' } },
  }.freeze

  def write_metadata(dir, name, deps, optional_deps = nil)
    repo = File.join(dir, name)
    FileUtils.mkdir_p(repo)
    metadata = {
      'name' => "simp-#{name}", 'version' => '1.0.0', 'author' => 'SIMP',
      'license' => 'Apache-2.0', 'summary' => 'spec fixture',
      'dependencies' => deps,
    }
    metadata['simp'] = { 'optional_dependencies' => optional_deps } if optional_deps
    File.write(File.join(repo, 'metadata.json'), JSON.pretty_generate(metadata) + "\n")
    repo
  end

  around(:each) do |example|
    require 'fileutils'
    @forge = FakeForge.new(FORGE_MODULES)
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  ensure
    @forge.stop
  end

  def run_update(repo_paths)
    run_task('update_metadata_deps.rb', 'repo_paths' => repo_paths, 'forge_api_url' => @forge.url)
  end

  it 'bumps only the out-of-range upper bound, renames superseded modules, and shares lookups' do
    repo_a = write_metadata(@dir, 'repo-a', [
      { 'name' => 'puppetlabs/stdlib', 'version_requirement' => '>= 8.0.0 < 10.0.0' },  # in range
      { 'name' => 'puppet/systemd', 'version_requirement' => '>= 4.0.2 < 7.0.0' },      # out of range
    ])
    repo_b = write_metadata(
      @dir, 'repo-b',
      [{ 'name' => 'herculesteam/augeasproviders_grub', 'version_requirement' => '>= 3.0.0 < 4.0.0' }],
      [{ 'name' => 'puppet/systemd', 'version_requirement' => '>= 4.0.2 < 7.0.0' }],    # optional dep, out of range
    )

    stdout, stderr, status = run_update([repo_a, repo_b])

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result['changed']).to be true

    a = JSON.parse(File.read(File.join(repo_a, 'metadata.json')))
    expect(a['dependencies'][0]['version_requirement']).to eq('>= 8.0.0 < 10.0.0') # untouched
    expect(a['dependencies'][1]['version_requirement']).to eq('>= 4.0.2 < 9.0.0')  # bumped upper only

    b = JSON.parse(File.read(File.join(repo_b, 'metadata.json')))
    expect(b['dependencies'][0]['name']).to eq('puppet-augeasproviders_grub')      # renamed
    expect(b['dependencies'][0]['version_requirement']).to eq('>= 3.0.0 < 6.0.0')  # and bumped
    expect(b['simp']['optional_dependencies'][0]['version_requirement']).to eq('>= 4.0.2 < 9.0.0')

    # One lookup per unique slug (+1 per chain hop), shared across repos:
    # stdlib, systemd, herculesteam-..., puppet-augeasproviders_grub
    expect(@forge.requests.length).to eq(4)
    expect(@forge.requests.tally.values).to all(eq(1))
  end

  it 'leaves a fully in-range repo untouched and reports changed: false for it' do
    repo = write_metadata(@dir, 'repo-c', [
      { 'name' => 'puppetlabs/stdlib', 'version_requirement' => '>= 8.0.0 < 10.0.0' },
    ])
    before = File.read(File.join(repo, 'metadata.json'))

    stdout, stderr, status = run_update([repo])

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result['changed']).to be false
    expect(result['repos']['repo-c']['changed']).to be false
    expect(File.read(File.join(repo, 'metadata.json'))).to eq(before) # byte-identical
  end

  it 'warns and skips non-two-bound ranges and unresolvable modules without failing' do
    repo = write_metadata(@dir, 'repo-d', [
      { 'name' => 'puppet/systemd', 'version_requirement' => '>= 99.0.0' },      # single bound, out of range
      { 'name' => 'simp/nosuchmodule', 'version_requirement' => '>= 1.0.0 < 2.0.0' }, # 404
    ])
    before = File.read(File.join(repo, 'metadata.json'))

    stdout, stderr, status = run_update([repo])

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result['repos']['repo-d']['changed']).to be false
    expect(result['repos']['repo-d']['skips'].join).to include('not a two-bound range')
    expect(result['repos']['repo-d']['skips'].join).to include('not resolvable')
    expect(File.read(File.join(repo, 'metadata.json'))).to eq(before)
  end

  it 'skips repos without a metadata.json' do
    empty = File.join(@dir, 'repo-e')
    FileUtils.mkdir_p(empty)

    stdout, stderr, status = run_update([empty])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['repos']['repo-e']).to include('changed' => false, 'skip' => 'no metadata.json')
  end

  it 'fails when repo_paths is missing' do
    _stdout, _stderr, status = run_task('update_metadata_deps.rb', {})
    expect(status).not_to be_success
  end
end
