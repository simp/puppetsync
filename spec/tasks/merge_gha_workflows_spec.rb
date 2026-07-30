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

  def run_merge(workflows)
    run_task('merge_gha_workflows.rb', 'workflows' => workflows)
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
    bumped = real_template.gsub('actions/checkout@v5', 'actions/checkout@v7')
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
            .gsub('actions/checkout@v5', 'actions/checkout@v7')
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
    expect(merged.scan('actions/checkout@v7').count).to eq(real_template.scan('actions/checkout@v5').count - 1)
    expect(merged.scan('actions/checkout@v5').count).to eq(1)
    # And apart from the grafted ref lines, output is byte-identical to the template
    expect(merged.gsub('actions/checkout@v7', 'actions/checkout@v5')).to eq(real_template)
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
    File.write(@wf, real_template.gsub('actions/checkout@v5', 'actions/checkout@v7'))
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

  it 'is idempotent' do
    stale = real_template.gsub('actions/checkout@v5', 'actions/checkout@v7').sub("name: PR Tests\n", "name: Old Name\n")
    File.write(@wf, stale)
    run_merge([{ 'path' => @wf, 'template' => real_template }])
    first_pass = File.read(@wf)

    stdout, stderr, status = run_merge([{ 'path' => @wf, 'template' => real_template }])

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)['changed']).to be false
    expect(File.read(@wf)).to eq(first_pass)
  end

  it 'fails when workflows param is missing' do
    _stdout, _stderr, status = run_task('merge_gha_workflows.rb', {})
    expect(status).not_to be_success
  end
end
