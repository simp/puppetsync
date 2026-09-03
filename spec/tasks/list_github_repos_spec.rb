require 'spec_helper'

describe 'task: list_github_repos' do
  # Modeled on real simp-org repos (see simp/puppetsync#55). Nothing reads a
  # `fork` flag any more, so the fixtures don't carry one; the comments say
  # which entries model forks.
  let(:org_repos) do
    [
      { 'name' => 'pupmod-simp-aide', 'full_name' => 'simp/pupmod-simp-aide',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 500,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'puppet-gpasswd', 'full_name' => 'simp/puppet-gpasswd',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 200,
        'has_issues' => true, 'has_pull_requests' => true },
      # Archived, flags still on
      { 'name' => 'pupmod-simp-ntpd', 'full_name' => 'simp/pupmod-simp-ntpd',
        'archived' => true, 'default_branch' => 'master', 'topics' => [], 'size' => 300,
        'has_issues' => true, 'has_pull_requests' => true },
      # Archived, flags off (the org turns them off as part of archival)
      { 'name' => 'pupmod-simp-archivedoff', 'full_name' => 'simp/pupmod-simp-archivedoff',
        'archived' => true, 'default_branch' => 'master', 'topics' => [], 'size' => 300,
        'has_issues' => false, 'has_pull_requests' => false },
      # Maintained forks: issues + PRs enabled
      { 'name' => 'rubygem-simp-rspec-puppet-facts', 'full_name' => 'simp/rubygem-simp-rspec-puppet-facts',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 100,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'pupmod-voxpupuli-selinux', 'full_name' => 'simp/pupmod-voxpupuli-selinux',
        'archived' => false, 'default_branch' => 'simp-master', 'topics' => [], 'size' => 400,
        'has_issues' => true, 'has_pull_requests' => true },
      # Mirror fork: issues + PRs disabled org-wide
      { 'name' => 'puppetlabs-apache', 'full_name' => 'simp/puppetlabs-apache',
        'archived' => false, 'default_branch' => 'main', 'topics' => [], 'size' => 900,
        'has_issues' => false, 'has_pull_requests' => false },
      # Only ONE of the two flags off still means mirror-ish: skip (both directions)
      { 'name' => 'pupmod-simp-issuesoff', 'full_name' => 'simp/pupmod-simp-issuesoff',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 70,
        'has_issues' => false, 'has_pull_requests' => true },
      { 'name' => 'pupmod-simp-prsoff', 'full_name' => 'simp/pupmod-simp-prsoff',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 70,
        'has_issues' => true, 'has_pull_requests' => false },
      # Gated out, but does NOT match the include globs: must not be reported
      { 'name' => 'unrelated-mirror', 'full_name' => 'simp/unrelated-mirror',
        'archived' => false, 'default_branch' => 'main', 'topics' => [], 'size' => 80,
        'has_issues' => false, 'has_pull_requests' => false },
      { 'name' => 'pupmod-simp-optout', 'full_name' => 'simp/pupmod-simp-optout',
        'archived' => false, 'default_branch' => 'master', 'topics' => ['puppetsync-ignore'], 'size' => 100,
        'has_issues' => true, 'has_pull_requests' => true },
      { 'name' => 'topic-tagged-tool', 'full_name' => 'simp/topic-tagged-tool',
        'archived' => false, 'default_branch' => 'main', 'topics' => ['simp-baseline'], 'size' => 50,
        'has_issues' => true, 'has_pull_requests' => true },
      # No flags at all (older API shape) and an explicit null: both are
      # "cannot tell" and must be included, loudly
      { 'name' => 'pupmod-simp-legacyfields', 'full_name' => 'simp/pupmod-simp-legacyfields',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 60 },
      { 'name' => 'pupmod-simp-nullflag', 'full_name' => 'simp/pupmod-simp-nullflag',
        'archived' => false, 'default_branch' => 'master', 'topics' => [], 'size' => 60,
        'has_issues' => nil, 'has_pull_requests' => true },
      { 'name' => 'empty-repo', 'full_name' => 'simp/empty-repo',
        'archived' => false, 'default_branch' => 'main', 'topics' => [], 'size' => 0,
        'has_issues' => true, 'has_pull_requests' => true },
    ]
  end

  PUPMOD_GLOBS = ['pupmod-*', 'puppet-*', 'rubygem-*'].freeze

  def run_list_raw(source)
    run_task('list_github_repos.rb', 'source' => source, 'repos' => org_repos)
  end

  def run_list(source)
    stdout, stderr, status = run_list_raw(source)
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
      # unknown flags must not exclude
      'https://github.com/simp/pupmod-simp-legacyfields',
      'https://github.com/simp/pupmod-simp-nullflag',
    )
  end

  it 'skips a repo when EITHER issues or pull requests are disabled' do
    result = run_list('org' => 'simp', 'include' => PUPMOD_GLOBS)

    expect(urls(result)).to include('https://github.com/simp/pupmod-simp-aide') # control
    expect(urls(result)).not_to include('https://github.com/simp/pupmod-simp-issuesoff') # issues off, PRs on
    expect(urls(result)).not_to include('https://github.com/simp/pupmod-simp-prsoff')    # PRs off, issues on
    expect(urls(result)).not_to include('https://github.com/simp/puppetlabs-apache')     # both off
  end

  it 'reports, by name, the include-matching repos the contributions gate alone removed' do
    result = run_list('org' => 'simp', 'include' => PUPMOD_GLOBS)

    gate_warning = result['warnings'].find { |w| w.include?('issues or pull requests are disabled') }
    expect(gate_warning).to start_with('2 repo(s)')
    expect(gate_warning).to include('pupmod-simp-issuesoff', 'pupmod-simp-prsoff')
    # Mirrors that never matched an include glob are not this gate's doing
    expect(gate_warning).not_to include('puppetlabs-apache', 'unrelated-mirror')
  end

  it 'includes repos whose API record lacks the flags (or carries null), and says so' do
    stdout, stderr, status = run_list_raw('org' => 'simp')

    expect(status).to be_success, stderr
    result = JSON.parse(stdout)
    flag_warning = result['warnings'].find { |w| w.include?('could not be applied') }
    expect(flag_warning).to include('pupmod-simp-legacyfields', 'pupmod-simp-nullflag')
    expect(stderr).to include('could not be applied') # visible on a direct task run too
  end

  it 'lets force_include bypass the contributions gate but nothing else' do
    result = run_list('org' => 'simp', 'force_include' => ['pupmod-simp-prsoff', 'empty-repo', 'pupmod-simp-optout'])

    expect(urls(result)).to include('https://github.com/simp/pupmod-simp-prsoff')
    expect(urls(result)).not_to include('https://github.com/simp/empty-repo')         # still empty
    expect(urls(result)).not_to include('https://github.com/simp/pupmod-simp-optout') # still opted out
    expect(result['warnings'].join).not_to include('pupmod-simp-prsoff')              # not reported as gated
  end

  it 'does not apply the contributions gate to archived repos, so an archived sweep sees all of them' do
    result = run_list('org' => 'simp', 'exclude_archived' => false)

    expect(urls(result)).to include(
      'https://github.com/simp/pupmod-simp-ntpd',
      'https://github.com/simp/pupmod-simp-archivedoff', # flags off, but archived: still in the sweep
    )
    expect(urls(result)).not_to include('https://github.com/simp/puppetlabs-apache') # live mirror: still out
  end

  it 'rejects the retired include_forks/exclude_forks keys with an explanation' do
    %w[include_forks exclude_forks].each do |key|
      _stdout, stderr, status = run_list_raw('org' => 'simp', key => ['x'])

      expect(status).not_to be_success
      expect(stderr).to include(key, 'retired', 'force_include')
    end
  end

  it 'rejects unknown source keys instead of silently ignoring a typo' do
    _stdout, stderr, status = run_list_raw('org' => 'simp', 'excludes' => ['pupmod-voxpupuli-selinux'])

    expect(status).not_to be_success
    expect(stderr).to include('unknown repos_source key(s): excludes')
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
      'https://github.com/simp/pupmod-simp-nullflag',
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

  it 'sorts output by repo name for stable snapshots' do
    result = run_list('org' => 'simp')
    expect(urls(result)).to eq(urls(result).sort_by { |u| u.split('/').last })
  end

  it 'fails without a source' do
    _stdout, _stderr, status = run_task('list_github_repos.rb', 'repos' => [])
    expect(status).not_to be_success
  end
end
