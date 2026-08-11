require 'spec_helper'

describe 'task: merge_gha_workflows' do
  let(:real_template) do
    File.read(File.join(REPO_ROOT, 'modules', 'profile', 'files', 'pupmod', '_github', 'workflows', 'pr_tests.yml'))
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @wf = File.join(dir, 'pr_tests.yml')
      example.run
    end
  end

  def run_merge(workflows, preserve_blocks: nil)
    params = { 'workflows' => workflows }
    params['preserve_blocks'] = preserve_blocks if preserve_blocks
    run_task('merge_gha_workflows.rb', params)
  end

  it 'writes the template when the target does not exist' do
    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]).to include('changed' => true, 'created' => true)
    expect(File.read(@wf)).to eq(real_template)
  end

  it 'is a no-op when the target matches the template' do
    File.write(@wf, real_template)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to include('changed' => false)
    expect(File.read(@wf)).to eq(real_template)
  end

  it 'preserves Renovate-bumped action refs when refreshing the template' do
    bumped = real_template.gsub('actions/checkout@v7', 'actions/checkout@v8')
    raise 'munge failed' if bumped == real_template
    File.write(@wf, bumped)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]['changed']).to be false
    expect(File.read(@wf)).to eq(bumped) # untouched: only refs differ, and they're preserved
  end

  it 'restores template structure while grafting existing refs onto it' do
    # Target: structurally stale (a job removed) AND Renovate-bumped
    stale = real_template
            .gsub('actions/checkout@v7', 'actions/checkout@v8')
            .sub(/^  puppet-syntax:.*?(?=^  \w)/m, '')
    raise 'munge failed' unless stale.length < real_template.length
    File.write(@wf, stale)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]['changed']).to be true
    merged = File.read(@wf)
    # Structure comes back from the template...
    expect(merged).to include('puppet-syntax:')
    # ...jobs that survived keep their bumped refs; the restored job takes
    # the template's ref (it has no counterpart in the existing file)
    expect(merged.scan('actions/checkout@v8').count).to eq(real_template.scan('actions/checkout@v7').count - 1)
    expect(merged.scan('actions/checkout@v7').count).to eq(1)
    # And apart from the grafted ref lines, output is byte-identical to the template
    expect(merged.gsub('actions/checkout@v8', 'actions/checkout@v7')).to eq(real_template)
  end

  it 'preserves pinned-digest refs with their trailing version comment' do
    template = <<~YAML
      jobs:
        build:
          steps:
            - uses: actions/checkout@v5
            - name: setup
              uses: ruby/setup-ruby@v1
    YAML
    pinned = <<~YAML
      jobs:
        build:
          steps:
            - uses: actions/checkout@8edcb1bdb4e267140fa742c62e395cd74f332709 # v7.0.0
            - name: setup
              uses: ruby/setup-ruby@ec106b438a1ff6ff109590de34ddc62c540232e0 # v1.244.0
    YAML
    File.write(@wf, pinned)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]['changed']).to be false
    expect(File.read(@wf)).to eq(pinned)
  end

  it 'uses the template ref for actions new to the template' do
    existing = <<~YAML
      jobs:
        build:
          steps:
            - uses: actions/checkout@v7
    YAML
    template = <<~YAML
      jobs:
        build:
          steps:
            - uses: actions/checkout@v5
            - uses: actions/upload-artifact@v4
    YAML
    File.write(@wf, existing)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }])

    expect(status).to be_success, stderr
    merged = File.read(@wf)
    expect(merged).to include('actions/checkout@v7')      # preserved
    expect(merged).to include('actions/upload-artifact@v4') # from template
  end

  it 'handles multiple workflow files in one invocation' do
    other = File.join(@dir, 'tag_deploy.yml')
    File.write(@wf, real_template.gsub('actions/checkout@v7', 'actions/checkout@v8'))
    File.write(other, "jobs:\n  x:\n    steps:\n      - uses: actions/checkout@v7\n")

    stdout, stderr, status = run_merge([
                                         { 'path' => @wf, 'template' => real_template },
                                         { 'path' => other, 'template' => "jobs:\n  x:\n    steps:\n      - uses: actions/checkout@v5\n" },
                                       ])

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    expect(result['files'].keys).to contain_exactly(@wf, other)
    expect(File.read(other)).to include('actions/checkout@v7')
  end

  it 'preserves other Renovate-managed values: ruby versions and container image tags' do
    template = <<~YAML
      jobs:
        spec:
          container:
            image: ghcr.io/simp/build:8.0.0
          steps:
            - uses: ruby/setup-ruby@v1
              with:
                ruby-version: '3.2'
        release:
          container: ruby:3.2
          steps:
            - uses: ruby/setup-ruby@v1
              with:
                ruby-version: '3.2'
    YAML
    # Renovate bumped each managed value — differently per job for ruby-version
    bumped = <<~YAML
      jobs:
        spec:
          container:
            image: ghcr.io/simp/build:9.1.0
          steps:
            - uses: ruby/setup-ruby@v1
              with:
                ruby-version: '3.4'
        release:
          container: ruby:3.3
          steps:
            - uses: ruby/setup-ruby@v1
              with:
                ruby-version: '4.0'
    YAML
    File.write(@wf, bumped)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]['changed']).to be false
    expect(File.read(@wf)).to eq(bumped)
  end

  it 'grafts non-uses managed values onto refreshed template structure' do
    template = <<~YAML
      name: New Name
      jobs:
        spec:
          container:
            image: ghcr.io/simp/build:8.0.0
          steps:
            - uses: ruby/setup-ruby@v1
              with:
                ruby-version: '3.2'
    YAML
    stale = template
            .sub('New Name', 'Old Name')
            .sub('ghcr.io/simp/build:8.0.0', 'ghcr.io/simp/build:9.1.0')
            .sub("ruby-version: '3.2'", "ruby-version: '3.4'")
    File.write(@wf, stale)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]['changed']).to be true
    merged = File.read(@wf)
    expect(merged).to include('New Name')                      # structure from template
    expect(merged).to include('ghcr.io/simp/build:9.1.0')      # preserved
    expect(merged).to include("ruby-version: '3.4'")           # preserved
  end

  it 'pairs ported-registry images by everything before the tag colon' do
    template = <<~YAML
      jobs:
        build:
          container:
            image: registry.internal:5000/simp/builder:8.0.0
    YAML
    bumped = template.sub(':8.0.0', ':9.2.0')
    File.write(@wf, bumped)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['files'][@wf]['changed']).to be false
    expect(File.read(@wf)).to eq(bumped)
  end

  it 'is idempotent' do
    stale = real_template.gsub('actions/checkout@v7', 'actions/checkout@v8').sub("name: PR Tests\n", "name: Old Name\n")
    File.write(@wf, stale)
    run_merge([{ 'path' => @wf, 'template' => real_template }])
    first_pass = File.read(@wf)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['changed']).to be false
    expect(File.read(@wf)).to eq(first_pass)
  end

  context 'with preserve_blocks' do
    let(:template) do
      <<~YAML
        name: PR Tests
        jobs:
          spec:
            steps:
              - uses: actions/checkout@v5
          acceptance:
            strategy:
              matrix:
                node: [almalinux9, almalinux10]
            steps:
              - uses: actions/checkout@v5
              - run: bundle exec rake beaker:suites[default,vagrant]
      YAML
    end

    it 'keeps a repo-specific block wholesale when refreshing the template' do
      # A repo with its own acceptance matrix (simplib-style), otherwise stale
      existing = <<~YAML
        name: Old Name
        jobs:
          spec:
            steps:
              - uses: actions/checkout@v7
          acceptance:
            strategy:
              matrix:
                suite: [default, custom]
                node: [oel8, oel9]
            steps:
              - uses: actions/checkout@v7
              - run: bundle exec rake beaker:suites[${{ matrix.suite }},docker]
      YAML
      File.write(@wf, existing)

      stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }],
                                         preserve_blocks: ['jobs.acceptance'])

      expect(status).to be_success, stderr
      result = JSON.parse(stdout)['files'][@wf]
      expect(result['changed']).to be true
      expect(result['preserved_blocks']).to eq(['jobs.acceptance'])
      merged = File.read(@wf)
      expect(merged).to include('name: PR Tests')                # structure from template
      expect(merged).to include('suite: [default, custom]')      # whole block preserved
      expect(merged).to include('beaker:suites[${{ matrix.suite }},docker]')
      expect(merged).not_to include('vagrant')
      # The preserved block keeps its own refs; scalar grafting still applies
      # inside it (both files say @v7 there, template's spec job gets @v7 too
      # since the existing spec step pairs with it)
      expect(merged.scan('actions/checkout@v7').count).to eq(2)
    end

    it 'appends the existing block when the template lacks it' do
      no_acceptance = template.sub(/^  acceptance:.*\z/m, '')
      existing = <<~YAML
        name: PR Tests
        jobs:
          spec:
            steps:
              - uses: actions/checkout@v5
          acceptance:
            steps:
              - run: bundle exec rake beaker:suites
      YAML
      File.write(@wf, existing)

      stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => no_acceptance }],
                                         preserve_blocks: ['jobs.acceptance'])

      expect(status).to be_success, stderr
      merged = File.read(@wf)
      expect(merged).to include('acceptance:')
      expect(merged).to include('rake beaker:suites')
      expect(Psych.safe_load(merged)['jobs'].keys).to contain_exactly('spec', 'acceptance')
    end

    it 'uses the template block when the existing file lacks the path' do
      existing = <<~YAML
        name: PR Tests
        jobs:
          spec:
            steps:
              - uses: actions/checkout@v5
      YAML
      File.write(@wf, existing)

      stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }],
                                         preserve_blocks: ['jobs.acceptance'])

      expect(status).to be_success, stderr
      merged = File.read(@wf)
      expect(merged).to include('node: [almalinux9, almalinux10]') # template's block
      expect(JSON.parse(stdout)['files'][@wf]['preserved_blocks']).to eq([])
    end

    it 'is idempotent' do
      existing = template
                 .sub('name: PR Tests', 'name: Old Name')
                 .sub('node: [almalinux9, almalinux10]', 'node: [oel8, oel9]')
      File.write(@wf, existing)
      run_merge([{ 'path' => @wf, 'template' => template }], preserve_blocks: ['jobs.acceptance'])
      first_pass = File.read(@wf)

      stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => template }],
                                         preserve_blocks: ['jobs.acceptance'])

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['changed']).to be false
      expect(File.read(@wf)).to eq(first_pass)
    end

    it 'preserves the fleet acceptance job byte-for-byte against the real template' do
      # The deployed fleet's acceptance job matches the template except for
      # repo-specific matrix/suite differences; splice a custom one in
      custom_acceptance = real_template[/^  acceptance:.*\z/m]
                          .gsub('almalinux9', 'oraclelinux8')
      existing = real_template.sub(/^  acceptance:.*\z/m, custom_acceptance)
      raise 'munge failed' if existing == real_template
      File.write(@wf, existing)

      stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }],
                                         preserve_blocks: ['jobs.acceptance'])

      expect(status).to be_success, stderr
      expect(JSON.parse(stdout)['files'][@wf]['changed']).to be false
      expect(File.read(@wf)).to eq(existing)
    end
  end

  it 'fails when workflows param is missing' do
    _stdout, _stderr, status = run_task('merge_gha_workflows.rb', {})
    expect(status).not_to be_success
  end
end
