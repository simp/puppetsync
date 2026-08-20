require 'spec_helper'

describe 'task: merge_gemfile' do
  let(:real_template) do
    File.read(File.join(REPO_ROOT, 'modules', 'profile', 'files', 'pupmod', 'Gemfile'))
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @gemfile = File.join(dir, 'Gemfile')
      example.run
    end
  end

  def run_merge(template:, remove_gems: nil)
    params = { 'path' => @gemfile, 'template' => template }
    params['remove_gems'] = remove_gems if remove_gems
    run_task('merge_gemfile.rb', params)
  end

  it 'writes the full template when the target does not exist' do
    stdout, stderr, status = run_merge(template: real_template)

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result['changed']).to be true
    expect(result['created']).to be true
    expect(File.read(@gemfile)).to eq(real_template)
  end

  context 'with a target derived from the baseline' do
    before(:each) { File.write(@gemfile, real_template) }

    it 'is a no-op on an identical file' do
      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to include('changed' => false, 'added' => [], 'removed' => [])
      expect(File.read(@gemfile)).to eq(real_template)
    end

    it 'never touches an existing gem version constraint' do
      # Simulate Renovate having bumped a pinned constraint
      munged = real_template.sub(
        "gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 6.0')",
        "gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 7.0')",
      )
      raise 'munge failed' if munged == real_template
      File.write(@gemfile, munged)

      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['changed']).to be false
      expect(File.read(@gemfile)).to include("'~> 7.0'")
    end

    it 'adds a template gem missing from its group, at the end of that group' do
      File.write(@gemfile, real_template.sub(/^\s*gem 'rake'\n/, ''))

      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to include('changed' => true, 'added' => ['rake'])
      content = File.read(@gemfile)
      test_group = content[/^group :test do.*?^end/m]
      expect(test_group).to include("gem 'rake'")
    end

    it 'adds attached comment lines together with the gem' do
      template = <<~GEMFILE
        source 'https://rubygems.org'

        group :test do
          # renovate: datasource=rubygems versioning=ruby
          gem 'new-gem', ENV.fetch('NEW_GEM_VERSION', '~> 1.0')
          gem 'rake'
        end
      GEMFILE
      File.write(@gemfile, <<~GEMFILE)
        source 'https://rubygems.org'

        group :test do
          gem 'rake'
        end
      GEMFILE

      stdout, stderr, status = run_merge(template: template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['added']).to eq(['new-gem'])
      content = File.read(@gemfile)
      expect(content.lines.map(&:rstrip)).to include(
        '  # renovate: datasource=rubygems versioning=ruby',
        "  gem 'new-gem', ENV.fetch('NEW_GEM_VERSION', '~> 1.0')",
      )
    end

    it 'creates a missing group block at EOF' do
      no_system_tests = real_template.sub(/^group :system_tests do.*?^end\n/m, '')
      raise 'munge failed' if no_system_tests == real_template
      File.write(@gemfile, no_system_tests)

      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)
      expect(result['changed']).to be true
      expect(result['added']).to include('beaker', 'simp-beaker-helpers')
      content = File.read(@gemfile)
      expect(content[/^group :system_tests do.*?^end/m]).to include("gem 'beaker'")
    end

    it 'removes gems in remove_gems along with an attached renovate comment' do
      with_extra = real_template.sub(
        "group :test do\n",
        "group :test do\n  # renovate: datasource=rubygems versioning=ruby\n  gem 'obsolete-lint-check', '~> 1.0'\n",
      )
      File.write(@gemfile, with_extra)

      stdout, stderr, status = run_merge(template: real_template, remove_gems: ['obsolete-lint-check'])

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to include('changed' => true, 'removed' => ['obsolete-lint-check'])
      content = File.read(@gemfile)
      expect(content).not_to include('obsolete-lint-check')
      expect(content.scan(/# renovate:/).count).to eq(real_template.scan(/# renovate:/).count)
    end

    it 'preserves custom gems the template knows nothing about' do
      with_custom = real_template.sub("group :development do\n", "group :development do\n  gem 'my-local-tool', path: '../tool'\n")
      File.write(@gemfile, with_custom)

      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['changed']).to be false
      expect(File.read(@gemfile)).to include("gem 'my-local-tool', path: '../tool'")
    end

    it 'brings referenced variable assignments along with added gems (transitively)' do
      File.write(@gemfile, <<~GEMFILE)
        source 'https://rubygems.org'

        group :test do
          gem 'rake'
        end
      GEMFILE

      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['added']).to include('openvox')
      content = File.read(@gemfile)
      test_group = content[/^group :test do.*?^end/m]
      # `gem 'openvox', openvox_version` requires openvox_version, which
      # itself requires puppet_version
      expect(test_group.index('puppet_version =')).to be < test_group.index('openvox_version =')
      expect(test_group.index('openvox_version =')).to be < test_group.index("gem 'openvox'")

      # The merged result must actually evaluate (undefined locals raise)
      evaluator = <<~RUBY
        def source(*); end
        def group(*); yield; end
        def gem(*, **); end
        eval(File.read(#{@gemfile.inspect}))
        puts 'EVAL_OK'
      RUBY
      out, eval_status = Open3.capture2e(RbConfig.ruby, '-e', evaluator)
      expect(eval_status).to be_success, out
      expect(out).to include('EVAL_OK')
    end

    it 'adds a top-level (ungrouped) template gem without raising' do
      template = <<~GEMFILE
        source 'https://rubygems.org'

        gem 'rake'

        group :test do
          gem 'rspec'
        end
      GEMFILE
      File.write(@gemfile, <<~GEMFILE)
        source 'https://rubygems.org'

        group :test do
          gem 'rspec'
        end
      GEMFILE

      stdout, stderr, status = run_merge(template: template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)).to include('changed' => true, 'added' => ['rake'])
      content = File.read(@gemfile)
      # Inserted at the top level, before the first group
      expect(content.index("gem 'rake'")).to be < content.index('group :test')
    end

    it 'is idempotent' do
      File.write(@gemfile, real_template.sub(/^\s*gem 'rake'\n/, ''))
      run_merge(template: real_template)
      first_pass = File.read(@gemfile)

      stdout, stderr, status = run_merge(template: real_template)

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['changed']).to be false
      expect(File.read(@gemfile)).to eq(first_pass)
    end
  end

  it 'fails when required params are missing' do
    _stdout, _stderr, status = run_task('merge_gemfile.rb', 'path' => @gemfile)
    expect(status).not_to be_success
  end
end
