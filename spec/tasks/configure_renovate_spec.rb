require 'spec_helper'

describe 'task: configure_renovate' do
  let(:shared_presets) do
    [
      'config:recommended',
      'github>simp/renovate-config',
      'github>simp/renovate-config:ruby.json',
    ]
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def renovate_config
    JSON.parse(File.read(File.join(@dir, 'renovate.json')))
  end

  it 'exits cleanly without creating a config when none exists' do
    _stdout, stderr, status = run_task('configure_renovate.rb', 'path' => @dir)

    expect(status).to be_success, stderr
    expect(File).not_to exist(File.join(@dir, 'renovate.json'))
  end

  it 'fails on a JSON5 config' do
    File.write(File.join(@dir, 'renovate.json5'), "{}\n")
    _stdout, _stderr, status = run_task('configure_renovate.rb', 'path' => @dir)
    expect(status).not_to be_success
  end

  it 'adds the shared presets to extends' do
    File.write(File.join(@dir, 'renovate.json'), "{}\n")

    _stdout, stderr, status = run_task('configure_renovate.rb', 'path' => @dir)

    expect(status).to be_success, stderr
    expect(renovate_config['extends']).to include(*shared_presets)
  end

  it 'preserves existing extends entries' do
    File.write(File.join(@dir, 'renovate.json'), JSON.generate('extends' => ['local>custom/preset']))

    _stdout, stderr, status = run_task('configure_renovate.rb', 'path' => @dir)

    expect(status).to be_success, stderr
    expect(renovate_config['extends']).to include('local>custom/preset', *shared_presets)
  end

  context 'with a Gemfile' do
    let(:gemfile_path) { File.join(@dir, 'Gemfile') }

    before(:each) do
      File.write(File.join(@dir, 'renovate.json'), "{}\n")
      File.write(gemfile_path, <<~GEMFILE)
        source 'https://rubygems.org'

        gem 'simp-beaker-helpers', '~> 1.28'
        gem 'rake'
      GEMFILE
    end

    it 'rewrites pinned gems to ENV-overridable versions with a renovate manager comment' do
      _stdout, stderr, status = run_task('configure_renovate.rb', 'path' => @dir)

      expect(status).to be_success, stderr
      lines = File.read(gemfile_path).lines(chomp: true)
      gem_line = lines.index { |l| l.include?('simp-beaker-helpers') }
      expect(lines[gem_line]).to include("ENV.fetch('SIMP_BEAKER_HELPERS_VERSION'")
      expect(lines[gem_line - 1]).to eq('# renovate: datasource=rubygems versioning=ruby')
      expect(lines).to include("gem 'rake'") # untouched
    end

    it 'is idempotent' do
      run_task('configure_renovate.rb', 'path' => @dir)
      first_pass = [File.read(gemfile_path), File.read(File.join(@dir, 'renovate.json'))]

      _stdout, stderr, status = run_task('configure_renovate.rb', 'path' => @dir)

      expect(status).to be_success, stderr
      second_pass = [File.read(gemfile_path), File.read(File.join(@dir, 'renovate.json'))]
      expect(second_pass).to eq(first_pass)
    end
  end
end
