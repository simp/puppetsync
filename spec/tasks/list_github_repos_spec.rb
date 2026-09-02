require 'spec_helper'

describe 'task: list_github_repos' do
  # Modeled on real simp-org repos (see simp/puppetsync#55)
  let(:org_repos) do
    [
      { 'name' => 'pupmod-simp-aide', 'full_name' => 'simp/pupmod-simp-aide',
        'fork' => false, 'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 500,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'puppet-gpasswd', 'full_name' => 'simp/puppet-gpasswd',
        'fork' => false, 'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 200,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'pupmod-simp-ntpd', 'full_name' => 'simp/pupmod-simp-ntpd',
        'fork' => false, 'archived' => true, 'default_branch' => 'master', 'topics' => [], 'size' => 300,
        'has_issues' => true, 'has_pull_requests' => true },
      # Maintained forks: issues + PRs enabled
      { 'name' => 'rubygem-simp-rspec-puppet-facts', 'full_name' => 'simp/rubygem-simp-rspec-puppet-facts',
        'fork' => true, 'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 100,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'pupmod-voxpupuli-selinux', 'full_name' => 'simp/pupmod-voxpupuli-selinux',
        'fork' => true, 'archived' => false, 'default_branch' => 'simp-master', 'topics' => [], 'size' => 400,
        'has_issues' => true, 'has_pull_requests' => true },
      # Mirror fork: issues + PRs disabled org-wide
      { 'name' => 'puppetlabs-apache', 'full_name' => 'simp/puppetlabs-apache',
        'fork' => true, 'archived' => false, 'default_branch' => 'main', 'topics' => [], 'size' => 900,
        'has_issues' => false, 'has_pull_requests' => false },
      # Only ONE of the two flags off still means mirror-ish: skip
      { 'name' => 'pupmod-simp-halfmirror', 'full_name' => 'simp/pupmod-simp-halfmirror',
        'fork' => false, 'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 70,
        'has_issues' => false, 'has_pull_requests' => true },
      { 'name' => 'pupmod-simp-optout', 'full_name' => 'simp/pupmod-simp-optout',
        'fork' => false, 'archived' => false, 'default_branch' => 'master', 'topics' => ['puppetsync-ignore'], 'size' => 100,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'topic-tagged-tool', 'full_name' => 'simp/topic-tagged-tool',
        'fork' => false, 'archived' => false, 'default_branch' => 'main', 'topics' => ['simp-baseline'], 'size' => 50,
        'has_issues' => true, 'has_pull_requests' => true },
      # No flags at all (older API shape): must still be included
      { 'name' => 'pupmod-simp-legacyfields', 'full_name' => 'simp/pupmod-simp-legacyfields',
        'fork' => false, 'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 60 },
      { 'name' => 'empty-repo', 'full_name' => 'simp/empty-repo',
        'fork' => false, 'archived' => false, 'default_branch' => 'main', 'topics' => [], 'size' => 0,
        'has_issues' => true, 'has_pull_requests' => true },
    ]
  end

  def run_list(source)
    stdout, stderr, status = run_task('list_github_repos.rb', 'source' => source, 'repos' => org_repos)
    expect(status).to be_success, stderr
    JSON.parse(stdout)
  end

  def urls(result)
    result['repos_config'].keys
  end

  it 'includes maintained forks and excludes mirrors, archived, empty, and opted-out repos by default' do
    result = run_list({ 'org' => 'simp' })

    expect(urls(result)).to contain_exactly(
      'https://github.com/simp/pupmod-simp-aide',
      'https://github.com/simp/puppet-gpasswd',
      'https://github.com/simp/topic-tagged-tool',
      # forks with issues+PRs enabled are maintained repos, not mirrors
      'https://github.com/simp/rubygem-simp-rspec-puppet-facts',
      'https://github.com/simp/pupmod-voxpupuli-selinux',
      # missing flags (older API shape) must not exclude
      'https://github.com/simp/pupmod-simp-legacyfields',
    )
  end

  it 'skips a repo when EITHER issues or pull requests are disabled' do
    result = run_list({ 'org' => 'simp' })

    expect(urls(result)).not_to include('https://github.com/simp/puppetlabs-apache')     # both off
    expect(urls(result)).not_to include('https://github.com/simp/pupmod-simp-halfmirror') # issues off
  end

  it 'warns that the retired include_forks/exclude_forks keys are ignored' do
    stdout, stderr, status = run_task('list_github_repos.rb',
                                      'source' => { 'org' => 'simp', 'include_forks' => ['x'] }, 'repos' => org_repos)

    expect(status).to be_success, stderr
    expect(stderr).to include('retired and ignored')
    # ...and they really are ignored: mirrors stay out, maintained forks stay in
    result = JSON.parse(stdout)
    expect(result['repos_config'].keys).to include('https://github.com/simp/pupmod-voxpupuli-selinux')
    expect(result['repos_config'].keys).not_to include('https://github.com/simp/puppetlabs-apache')
  end

  it 'takes each branch from the API default_branch' do
    result = run_list({ 'org' => 'simp' })

    expect(result['repos_config']['https://github.com/simp/pupmod-voxpupuli-selinux']).to eq('branch' => 'simp-master')
    expect(result['repos_config']['https://github.com/simp/pupmod-simp-aide']).to eq('branch' => 'master')
  end

  it 'filters by include name globs without assuming pupmod-simp-*' do
    result = run_list('org' => 'simp', 'include' => ['pupmod-*', 'puppet-*'])

    expect(urls(result)).to contain_exactly(
      'https://github.com/simp/pupmod-simp-aide',
      'https://github.com/simp/puppet-gpasswd',
      'https://github.com/simp/pupmod-voxpupuli-selinux',
      'https://github.com/simp/pupmod-simp-legacyfields',
    )
  end

  it 'admits repos by topic even when name globs miss them' do
    result = run_list('org' => 'simp', 'include' => ['pupmod-*'], 'include_topics' => ['simp-baseline'])

    expect(urls(result)).to include(
      'https://github.com/simp/pupmod-simp-aide',
      'https://github.com/simp/topic-tagged-tool',
    )
  end

  it 'honors explicit exclude globs above all' do
    result = run_list('org' => 'simp', 'exclude' => ['pupmod-simp-aide'])

    expect(urls(result)).not_to include('https://github.com/simp/pupmod-simp-aide')
  end

  it 'can include archived repos when asked' do
    result = run_list('org' => 'simp', 'exclude_archived' => false)

    expect(urls(result)).to include('https://github.com/simp/pupmod-simp-ntpd')
  end

  it 'sorts output by repo name for stable snapshots' do
    result = run_list('org' => 'simp')
    expect(urls(result)).to eq(urls(result).sort_by { |u| u.split('/').last })
  end

  it 'fails without a source' do
    _stdout, _stderr, status = run_task('list_github_repos.rb', 'repos' => [])
    expect(status).not_to be_success
  end
end
