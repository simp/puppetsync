require 'spec_helper'

describe 'task: bump_module_version' do
  def git(*args)
    out, status = Open3.capture2e('git', '-C', @repo, *args)
    raise "git #{args.join(' ')} failed:\n#{out}" unless status.success?
    out
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @repo = dir
      git('init', '-b', 'master')
      git('config', 'user.email', 'ci@example.com')
      git('config', 'user.name', 'CI')
      File.write(File.join(@repo, 'metadata.json'), JSON.pretty_generate(
        'name' => 'simp-fixture', 'version' => '1.2.3', 'author' => 'SIMP',
        'license' => 'Apache-2.0', 'summary' => 'spec fixture', 'dependencies' => [],
      ) + "\n")
      File.write(File.join(@repo, 'CHANGELOG'), <<~CHANGELOG)
        * Tue Jun 02 2026 Someone Else <someone@example.com> - 1.2.3
        - Prior entry

      CHANGELOG
      git('add', '-A')
      git('commit', '-m', 'initial')
      example.run
    end
  end

  def run_bump(overrides = {})
    run_task('bump_module_version.rb', {
      'repo_path'         => @repo,
      'changelog_message' => '[puppetsync] Update metadata.json dependency ranges from the Forge',
      'author'            => 'Steven Pritchard',
      'email'             => 'steve@sicura.us',
    }.merge(overrides))
  end

  def dirty!
    File.write(File.join(@repo, 'metadata.json'),
               File.read(File.join(@repo, 'metadata.json')).sub('"1.2.3"', '"1.2.3"') + "\n")
  end

  it 'skips (without bumping) when the working tree is clean' do
    stdout, stderr, status = run_bump

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to include('changed' => false, 'skip' => /working tree clean/)
    expect(JSON.parse(File.read(File.join(@repo, 'metadata.json')))['version']).to eq('1.2.3')
  end

  it 'patch-bumps a dirty repo by default and prepends a matching CHANGELOG entry' do
    dirty!

    stdout, stderr, status = run_bump

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to include('changed' => true, 'from' => '1.2.3', 'to' => '1.2.4')
    expect(JSON.parse(File.read(File.join(@repo, 'metadata.json')))['version']).to eq('1.2.4')
    changelog = File.read(File.join(@repo, 'CHANGELOG'))
    entry, rest = changelog.split("\n\n", 2)
    expect(entry).to match(
      /\A\* (Mon|Tue|Wed|Thu|Fri|Sat|Sun) [A-Z][a-z]{2} \d{2} \d{4} Steven Pritchard <steve@sicura\.us> - 1\.2\.4\n- \[puppetsync\] Update metadata\.json dependency ranges from the Forge\z/,
    )
    expect(rest).to start_with('* Tue Jun 02 2026') # prior entry intact
  end

  it 'minor-bumps when asked' do
    dirty!

    stdout, stderr, status = run_bump('bump' => 'minor')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to include('from' => '1.2.3', 'to' => '1.3.0')
  end

  it 'withholds the bump when there is no CHANGELOG' do
    File.delete(File.join(@repo, 'CHANGELOG'))
    git('add', '-A'); git('commit', '-qm', 'drop changelog')
    dirty!

    stdout, stderr, status = run_bump

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to include('changed' => false, 'skip' => /no CHANGELOG/)
    expect(JSON.parse(File.read(File.join(@repo, 'metadata.json')))['version']).to eq('1.2.3')
  end

  it 'withholds the bump for non-X.Y.Z versions' do
    metadata = JSON.parse(File.read(File.join(@repo, 'metadata.json')))
    metadata['version'] = '2.0.0-beta1'
    File.write(File.join(@repo, 'metadata.json'), JSON.pretty_generate(metadata) + "\n")
    git('add', '-A'); git('commit', '-qm', 'prerelease')
    dirty!

    stdout, stderr, status = run_bump

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to include('changed' => false, 'skip' => /not plain X\.Y\.Z/)
  end

  it 'fails when required params are missing' do
    _stdout, _stderr, status = run_task('bump_module_version.rb', 'repo_path' => @repo)
    expect(status).not_to be_success
  end
end
