require_relative 'plan_spec_helper'
require 'tmpdir'
require 'yaml'

describe 'plan: puppetsync (dynamic inventory, #55)' do
  include_context 'puppetsync plan specs'

  let(:puppetsync_config) do
    {
      'puppetsync' => {
        'plans' => {
          'sync' => {
            'clone_git_repos'        => false,
            'filter_permitted_repos' => false,
            'stages'                 => [],
          },
        },
      },
      'git' => { 'feature_branch' => 'SIMP-TEST' },
    }
  end

  let(:repos_source) do
    { 'org' => 'simp', 'include' => ['repo-*'] }
  end

  let(:generated_config) do
    {
      'https://github.com/simp/repo-x' => { 'branch' => 'main' },
      'https://github.com/simp/repo-y' => { 'branch' => 'master' },
    }
  end

  def unwrap(value)
    value.respond_to?(:unwrap) ? value.unwrap : value
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @project_dir = dir
      FileUtils.mkdir_p(File.join(dir, 'data', 'sync', 'repolists'))
      example.run
    end
  end

  def run_sync(extra = {})
    run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'config'            => 'spec-run',
      'puppetsync_config' => puppetsync_config,
      'repos_config'      => {},
      'repos_source'      => repos_source,
    }.merge(extra))
  end

  it 'builds the inventory from the listing task and snapshots it as a normal repolist' do
    allow_out_message
    sources_seen = []
    expect_task('puppetsync::list_github_repos').with_targets(['localhost']).return do |targets:, task:, params:|
      sources_seen << params.transform_values { |v| unwrap(v) }
      Bolt::ResultSet.new(targets.map do |t|
        Bolt::Result.new(t, value: { 'repos_config' => generated_config, 'count' => 2 }, action: 'task', object: task)
      end)
    end

    result = run_sync

    expect(result.ok?).to be(true), result.value.to_s
    expect(sources_seen.first['source']).to eq(repos_source)

    snapshot = File.join(@project_dir, 'data', 'sync', 'repolists', 'generated-spec-run.yaml')
    expect(File).to exist(snapshot)
    expect(YAML.load_file(snapshot)).to eq('puppetsync::repos_config' => generated_config)
  end

  it 'prints the listing task warnings, which a plan run would otherwise never show' do
    allow_out_message
    allow_task('puppetsync::list_github_repos').return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map do |t|
        Bolt::Result.new(t, value: { 'repos_config' => generated_config, 'count' => 2,
                                     'warnings' => ['1 repo(s) matching the include filters were excluded because issues or pull requests are disabled: pupmod-simp-x'] },
                                    action: 'task', object: task)
      end)
    end
    expect_out_message.with_params('== WARNING (dynamic inventory): 1 repo(s) matching the include filters were excluded because issues or pull requests are disabled: pupmod-simp-x')

    result = run_sync

    expect(result.ok?).to be(true), result.value.to_s
  end

  it 'merges static repos_config entries on top of the generated list (static wins)' do
    allow_out_message
    allow_task('puppetsync::list_github_repos').return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map do |t|
        Bolt::Result.new(t, value: { 'repos_config' => generated_config, 'count' => 2 }, action: 'task', object: task)
      end)
    end
    static = {
      'https://github.com/simp/repo-x'      => { 'branch' => 'static-override' },
      'https://github.com/simp/repo-static' => { 'branch' => 'master' },
    }

    result = run_sync('repos_config' => static)

    expect(result.ok?).to be(true), result.value.to_s
    snapshot = YAML.load_file(File.join(@project_dir, 'data', 'sync', 'repolists', 'generated-spec-run.yaml'))
    merged = snapshot['puppetsync::repos_config']
    expect(merged['https://github.com/simp/repo-x']).to eq('branch' => 'static-override')
    expect(merged.keys).to contain_exactly(
      'https://github.com/simp/repo-x',
      'https://github.com/simp/repo-y',
      'https://github.com/simp/repo-static',
    )
  end

  it 'does not call the listing task in list_pipeline_stages mode' do
    allow_out_message
    # No task stubs declared: a listing call would raise

    result = run_sync('options' => { 'list_pipeline_stages' => true })

    expect(result.ok?).to be(true), result.value.to_s
    expect(Dir.glob(File.join(@project_dir, 'data', 'sync', 'repolists', 'generated-*'))).to be_empty
  end

  it 'uses the static repos_config unchanged when no repos_source is given' do
    allow_out_message
    static = { 'https://github.com/simp/repo-static' => { 'branch' => 'master' } }

    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'config'            => 'spec-run',
      'puppetsync_config' => puppetsync_config,
      'repos_config'      => static,
    })

    expect(result.ok?).to be(true), result.value.to_s
    expect(Dir.glob(File.join(@project_dir, 'data', 'sync', 'repolists', 'generated-*'))).to be_empty
  end
end
