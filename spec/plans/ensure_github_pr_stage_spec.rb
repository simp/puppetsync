require_relative 'plan_spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'plan: puppetsync (ensure_github_pr stage)' do
  include_context 'puppetsync plan specs'

  let(:repos_config) do
    { 'https://github.com/simp/repo-a' => { 'branch' => 'master' } }
  end

  def puppetsync_config(github_opts = {})
    {
      'puppetsync' => {
        'plans' => {
          'sync' => {
            'clone_git_repos'        => false,
            'filter_permitted_repos' => false,
            'github_api_delay_seconds' => 0,
            'stages'                 => ['ensure_github_pr'],
          },
        },
      },
      'git'    => {
        'feature_branch' => 'SIMP-TEST',
        'commit_message' => "[puppetsync] spec test\n\nbody",
      },
      'github' => github_opts,
    }
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @project_dir = dir
      FileUtils.mkdir_p(File.join(dir, '_repos', 'repo-a'))
      example.run
    end
  end

  def unwrap(value)
    value.respond_to?(:unwrap) ? value.unwrap : value
  end

  def run_pr_stage(github_opts)
    calls = []
    expect_task('puppetsync::ensure_github_pr').return do |targets:, task:, params:|
      calls << params.transform_values { |v| unwrap(v) }
      Bolt::ResultSet.new(targets.map { |t|
        Bolt::Result.new(t, value: { 'pr_created' => true, 'pr_url' => 'https://x/1' }, action: 'task', object: task)
      })
    end
    allow_out_message

    # github_token defaults from ENV['GITHUB_API_TOKEN'] (see plan_spec_helper)
    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'puppetsync_config' => puppetsync_config(github_opts),
      'repos_config'      => repos_config,
    })
    expect(result.ok?).to be(true), result.value.to_s
    calls.first
  end

  it 'creates PRs as drafts when github.draft is true' do
    params = run_pr_stage('draft' => true)
    expect(params['draft']).to be(true)
  end

  it 'creates PRs ready-for-review by default' do
    params = run_pr_stage({})
    expect(params['draft']).to be(false)
  end
end
