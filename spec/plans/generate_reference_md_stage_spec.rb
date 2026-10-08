require_relative 'plan_spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'plan: puppetsync (generate_reference_md stage)' do
  include_context 'puppetsync plan specs'

  let(:repos_config) do
    { 'https://github.com/simp/repo-a' => { 'branch' => 'master' } }
  end

  def puppetsync_config(stages)
    {
      'puppetsync' => {
        'plans' => {
          'sync' => {
            'clone_git_repos'        => false,
            'filter_permitted_repos' => false,
            'stages'                 => stages,
          },
        },
      },
      'git' => { 'feature_branch' => 'SIMP-TEST', 'commit_message' => 'spec commit' },
    }
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @project_dir = dir
      repo = File.join(dir, '_repos', 'repo-a')
      FileUtils.mkdir_p(repo)
      File.write(File.join(repo, 'metadata.json'), <<~JSON)
        {
          "name": "simp-repoa", "version": "1.0.0", "author": "SIMP",
          "license": "Apache-2.0", "summary": "spec fixture", "dependencies": []
        }
      JSON
      example.run
    end
  end

  def run_sync(stages)
    calls = []
    allow_task('puppetsync::generate_reference_md').return do |targets:, task:, params:|
      calls << params
      Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: { 'changed' => false }, action: 'task', object: task) })
    end
    allow_task('puppetsync::git_commit').return do |targets:, task:, params:|
      Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: { 'changed' => false }, action: 'task', object: task) })
    end
    allow_task('puppetsync::install_gems').always_return({})
    allow_out_message

    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'puppetsync_config' => puppetsync_config(stages),
      'repos_config'      => repos_config,
    })
    expect(result.ok?).to be(true), result.value.to_s
    calls
  end

  it 'refreshes REFERENCE.md in changed repos when a committing session does not list the stage' do
    calls = run_sync(['git_commit_changes'])

    expect(calls.length).to eq(1)
    expect(File.basename(calls.first['repo_path'])).to eq('repo-a')
    expect(calls.first['only_changed']).to be(true)
  end

  it 'regenerates unconditionally when the session lists the stage' do
    calls = run_sync(%w[generate_reference_md git_commit_changes])

    expect(calls.length).to eq(1)
    expect(calls.first['only_changed']).to be(false)
  end

  it 'does not run in a session that does not commit' do
    expect(run_sync(['install_gems'])).to be_empty
  end
end
