require_relative 'plan_spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'plan: puppetsync (merge_github_workflows stage)' do
  include_context 'puppetsync plan specs'

  let(:repos_config) do
    { 'https://github.com/simp/repo-a' => { 'branch' => 'master' } }
  end

  def puppetsync_config(stage_opts = {})
    {
      'puppetsync' => {
        'plans' => {
          'sync' => {
            'clone_git_repos'        => false,
            'filter_permitted_repos' => false,
            'stages'                 => ['merge_github_workflows'],
          }.merge(stage_opts),
        },
      },
      'git' => { 'feature_branch' => 'SIMP-TEST' },
    }
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @project_dir = dir
      repo = File.join(dir, '_repos', 'repo-a')
      FileUtils.mkdir_p(File.join(repo, '.github', 'workflows'))
      File.write(File.join(repo, 'metadata.json'), <<~JSON)
        {
          "name": "simp-repoa", "version": "1.0.0", "author": "SIMP",
          "license": "Apache-2.0", "summary": "spec fixture", "dependencies": []
        }
      JSON
      File.write(File.join(repo, '.github', 'workflows', 'release_rpms.yml'), "name: stale\n")
      File.write(File.join(repo, '.github', 'workflows', 'pr_tests.yml'), "name: stale\n")
      File.write(File.join(repo, '.github', 'workflows', 'custom.yml'), "name: repo-specific\n")
      example.run
    end
  end

  def run_merge_stage(stage_opts = {})
    calls = []
    expect_task('puppetsync::merge_gha_workflows').return do |targets:, task:, params:|
      calls << params
      Bolt::ResultSet.new(targets.map { |t| Bolt::Result.new(t, value: { 'changed' => false }, action: 'task', object: task) })
    end
    allow_out_message

    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'puppetsync_config' => puppetsync_config(stage_opts),
      'repos_config'      => repos_config,
    })
    expect(result.ok?).to be(true), result.value.to_s
    calls.first
  end

  it 'merges every templated workflow (and skips untemplated ones) by default' do
    params = run_merge_stage

    files = params['workflows'].map { |wf| File.basename(wf['path']) }
    expect(files).to contain_exactly('release_rpms.yml', 'pr_tests.yml') # custom.yml has no template
    templated = params['workflows'].find { |wf| wf['path'].end_with?('release_rpms.yml') }
    expect(templated['template']).to include('ghcr.io/simp/').or include('simp_builder_docker_image')
  end

  it 'scopes the merge to the session-configured files list' do
    params = run_merge_stage('merge_github_workflows' => { 'files' => ['release_rpms.yml'] })

    files = params['workflows'].map { |wf| File.basename(wf['path']) }
    expect(files).to contain_exactly('release_rpms.yml')
  end

  it 'includes ensure_files workflows that do not exist in the repo yet' do
    params = run_merge_stage('merge_github_workflows' => {
                               'files'        => ['create_release_tag.yml'],
                               'ensure_files' => ['create_release_tag.yml'],
                             })

    files = params['workflows'].map { |wf| File.basename(wf['path']) }
    expect(files).to contain_exactly('create_release_tag.yml')
    templated = params['workflows'].first
    expect(templated['template']).to include('simp/gha-workflows')
  end

  it 'passes the session-configured preserve_blocks through to the task' do
    params = run_merge_stage('merge_github_workflows' => { 'preserve_blocks' => ['jobs.acceptance'] })

    expect(params['preserve_blocks']).to eq(['jobs.acceptance'])
  end

  it 'classifies a repo with a gemspec as a rubygem, excluding it from the merge' do
    # A gem can carry a pupmod-shaped metadata.json (compliance_engine does);
    # the gemspec must win or the gem's custom workflows get flattened
    File.write(File.join(@project_dir, '_repos', 'repo-a', 'repo-a.gemspec'), <<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = 'repo-a'
      end
    GEMSPEC
    allow_out_message

    # No merge_gha_workflows stub: the plan must not call it for a rubygem
    result = run_plan('puppetsync', {
      'project_dir'       => @project_dir,
      'puppetsync_config' => puppetsync_config,
      'repos_config'      => repos_config,
    })
    expect(result.ok?).to be(true), result.value.to_s
  end

  it 'merges into a rubygem when the session widens project_types to a shared template' do
    File.write(File.join(@project_dir, '_repos', 'repo-a', 'repo-a.gemspec'), <<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = 'repo-a'
      end
    GEMSPEC
    File.write(File.join(@project_dir, '_repos', 'repo-a', '.github', 'workflows', 'add_new_issue_to_triage_project.yml'),
               "name: stale\n")

    params = run_merge_stage('merge_github_workflows' => {
                               'project_types' => %w[pupmod pupmod_skeleton rubygem],
                               'files'         => ['add_new_issue_to_triage_project.yml'],
                             })

    files = params['workflows'].map { |wf| File.basename(wf['path']) }
    expect(files).to contain_exactly('add_new_issue_to_triage_project.yml') # scoped: pr_tests.yml untouched
    expect(params['workflows'].first['template']).to include('orgs/simp/projects/11')
  end
end
