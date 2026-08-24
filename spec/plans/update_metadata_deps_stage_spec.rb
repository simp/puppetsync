require_relative 'plan_spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'plan: puppetsync (update_metadata_deps stage)' do
  include_context 'puppetsync plan specs'

  let(:repos_config) do
    {
      'https://github.com/simp/repo-a' => { 'branch' => 'master' },
      'https://github.com/simp/repo-b' => { 'branch' => 'main' },
    }
  end

  let(:puppetsync_config) do
    {
      'puppetsync' => {
        'plans' => {
          'sync' => {
            'clone_git_repos'        => false,
            'filter_permitted_repos' => false,
            'stages'                 => ['update_metadata_deps'],
            'bump_module_version'    => {
              'bump'              => 'minor',
              'changelog_message' => '[puppetsync] specs',
              'author'            => 'Spec Author',
              'email'             => 'spec@example.com',
            },
          },
        },
      },
      'git' => { 'feature_branch' => 'SIMP-TEST' },
    }
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @project_dir = dir
      %w[repo-a repo-b].each do |name|
        repo = File.join(dir, '_repos', name)
        FileUtils.mkdir_p(repo)
        File.write(File.join(repo, 'metadata.json'), <<~JSON)
          {
            "name": "simp-#{name}", "version": "1.0.0", "author": "SIMP",
            "license": "Apache-2.0", "summary": "spec fixture", "dependencies": []
          }
        JSON
      end
      # repo-b is a rubygem (gemspec wins over metadata.json) and must be excluded
      File.write(File.join(dir, '_repos', 'repo-b', 'repo-b.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = 'repo-b'
        end
      GEMSPEC
      example.run
    end
  end

  it 'runs ONE task invocation covering only the pupmod repos' do
    calls = []
    expect_task('puppetsync::update_metadata_deps').be_called_times(1).return do |targets:, task:, params:|
      calls << { 'targets' => targets.map(&:name), 'params' => params }
      Bolt::ResultSet.new(targets.map { |t|
        Bolt::Result.new(t, value: { 'changed' => true, 'forge_requests' => 3, 'repos' => {} }, action: 'task', object: task)
      })
    end
    allow_out_message

    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'puppetsync_config' => puppetsync_config,
      'repos_config'      => repos_config,
    })

    expect(result.ok?).to be(true), result.value.to_s
    expect(calls.length).to eq(1)
    expect(calls.first['targets']).to eq(['localhost'])
    repo_paths = calls.first['params']['repo_paths']
    expect(repo_paths.map { |p| File.basename(p) }).to contain_exactly('repo-a') # rubygem excluded
  end

  it 'passes the session bump options through to bump_module_version' do
    config = puppetsync_config
    config['puppetsync']['plans']['sync']['stages'] = ['bump_module_version']
    bumps = []
    expect_task('puppetsync::bump_module_version').return do |targets:, task:, params:|
      bumps << params.transform_values { |v| v.respond_to?(:unwrap) ? v.unwrap : v }
      Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: { 'changed' => false }, action: 'task', object: task) })
    end
    allow_out_message

    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'puppetsync_config' => config,
      'repos_config'      => repos_config,
    })

    expect(result.ok?).to be(true), result.value.to_s
    expect(bumps.length).to eq(1) # pupmod repo-a only; rubygem repo-b excluded
    expect(bumps.first).to include(
      'bump'              => 'minor',
      'changelog_message' => '[puppetsync] specs',
      'author'            => 'Spec Author',
      'email'             => 'spec@example.com',
    )
    expect(File.basename(bumps.first['repo_path'])).to eq('repo-a')
  end
end
