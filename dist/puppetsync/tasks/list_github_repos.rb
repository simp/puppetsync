#!/opt/puppetlabs/bolt/bin/ruby
#
# Build a puppetsync repos_config hash dynamically from the GitHub API
# (simp/puppetsync#55), so repolists don't have to be hand-maintained.
#
# ==============================================================================
# The inventory rule (canonical statement -- README, github-org.yaml and the
# task metadata point here rather than restating it)
#
# A repo is in the inventory when ALL of these hold:
#
#   1. it is not archived (unless `exclude_archived: false`)
#   2. it is not empty (size > 0) -- there is nothing to clone
#   3. its name matches no `exclude` glob
#   4. it carries no topic in `exclude_topics` (default ['puppetsync-ignore']:
#      set that topic on a repo in GitHub to opt it out without touching
#      puppetsync)
#   5. its name matches an `include` glob, or it carries a topic in
#      `include_topics` (defaults ['*'] / none)
#   6. it accepts contributions: issues AND pull requests are enabled.
#      puppetsync's whole output is a PR, so a repo that cannot receive one
#      is definitionally out. The simp org turns both off on every fork that
#      exists only as a mirror, so this one signal separates mirrors from
#      maintained repos, forks included -- there is no fork allow-list.
#
# Rule 6 has three deliberate edges:
#
#   - It is skipped for ARCHIVED repos. Archival turns the flags off too, so
#     gating them would make `exclude_archived: false` silently drop most of
#     what it exists to include.
#   - `force_include` globs bypass it AND rule 5 (rules 1-4 still apply):
#     listing a name means "I want this repo, whatever its name or flags",
#     which is what the retired include_forks meant. This is the lever for a
#     maintained repo whose flags are off -- GitHub creates forks with issues
#     disabled, and admins turn issues off as a pre-archival step. A
#     force_include glob that matches nothing in the org is reported, so a
#     typo cannot no-op silently.
#   - A repo whose API record LACKS the flags (or carries null) is included,
#     and reported: the gate must never silently become a no-op or silently
#     empty the inventory because the response shape changed.
#
# Everything the gate excludes among repos that passed the include filters
# is reported by name, so convention drift (a maintained repo that lost its
# flags) is visible immediately rather than surfacing as a missing PR months
# later. Every repo gets exactly one verdict (kept?, reason), and both the
# selection and the reports are derived from those verdicts, so the two
# cannot disagree.
#
# Reports go to stderr AND into the result's `warnings` array; the plan
# prints the latter, because a plan run does not show task stderr.
#
# `exclude_forks` / `include_forks` are RETIRED and rejected, as is any key
# this task does not know: a typo'd key would otherwise no-op silently.
# ==============================================================================
#
# Each repo's branch comes from the API's default_branch (e.g.
# pupmod-voxpupuli-selinux uses 'simp-master').
#
# NOTE: this intentionally does NOT decide what kind of project a repo is —
# `puppetsync::filter_permitted_repos` still applies project_type filtering
# after the clone, which is the safety net for name-pattern false positives.

require 'json'
require 'net/http'
require 'uri'

PER_PAGE = 100
KNOWN_SOURCE_KEYS   = %w[org include exclude force_include include_topics exclude_topics exclude_archived].freeze
RETIRED_SOURCE_KEYS = %w[include_forks exclude_forks].freeze

# Transient failures (network errors, 5xx) are retried with backoff so a
# GitHub blip doesn't abort a whole (possibly scheduled) run; 4xx fails fast
def fetch_page(uri, token, attempts: 3)
  attempt = 0
  begin
    attempt += 1
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github+json'
    request['X-GitHub-Api-Version'] = '2022-11-28'
    request['Authorization'] = "Bearer #{token}" if token && !token.empty?
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Net::HTTPFatalError.new("GitHub API returned #{response.code}", response) if response.code.start_with?('5')
    raise("ERROR: GitHub API returned #{response.code} for #{uri.path}: #{response.body.to_s[0, 300]}") unless response.code == '200'

    response.body
  rescue Net::HTTPFatalError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    raise("ERROR: GitHub API request for #{uri.path} failed after #{attempts} attempts: #{e.message}") if attempt >= attempts

    warn "== retrying #{uri.path} after error (attempt #{attempt}/#{attempts}): #{e.message}"
    sleep(2 * attempt)
    retry
  end
end

def fetch_org_repos(org, token)
  repos = []
  page = 1
  loop do
    body = fetch_page(URI("https://api.github.com/orgs/#{org}/repos?type=all&per_page=#{PER_PAGE}&page=#{page}"), token)
    batch = JSON.parse(body)
    repos.concat(batch)
    break if batch.size < PER_PAGE

    page += 1
  end
  repos
end

def validate_source!(source)
  retired = source.keys & RETIRED_SOURCE_KEYS
  unless retired.empty?
    raise("ERROR: repos_source key(s) #{retired.join(', ')} are retired and no longer honoured: the inventory " \
          'now includes any repo with issues and pull requests enabled (see the header of ' \
          'tasks/list_github_repos.rb). Remove them from the repolist; use force_include for a repo with the flags off.')
  end
  unknown = source.keys - KNOWN_SOURCE_KEYS
  return if unknown.empty?

  raise("ERROR: unknown repos_source key(s): #{unknown.join(', ')} (known keys: #{KNOWN_SOURCE_KEYS.join(', ')})")
end

def glob_match?(name, globs)
  globs.any? { |glob| File.fnmatch(glob, name) }
end

# true / false when the API record carries both flags; nil when either is
# absent or null, which the caller treats as "cannot tell" rather than as
# either answer
def contributions_enabled?(repo)
  flags = [repo['has_issues'], repo['has_pull_requests']]
  return nil if flags.any?(&:nil?)

  flags.all?
end

# One verdict per repo: [kept?, reason]. The rule numbers are the header's.
def verdict(repo, opts)
  name   = repo['name']
  topics = repo['topics'] || []
  return [false, :archived]  if opts[:exclude_archived] && repo['archived']          # 1
  return [false, :empty]     if repo['size'].to_i.zero?                               # 2
  return [false, :excluded]  if glob_match?(name, opts[:exclude_globs])               # 3
  return [false, :opted_out] if topics.any? { |t| opts[:exclude_topics].include?(t) } # 4
  return [true,  :forced]    if glob_match?(name, opts[:force_include])               # bypasses 5 + 6
  return [false, :unmatched] unless glob_match?(name, opts[:include_globs]) ||        # 5
                                    topics.any? { |t| opts[:include_topics].include?(t) }
  return [true,  :archived_unchecked] if repo['archived']                             # 6 skipped: see header

  case contributions_enabled?(repo)                                                   # 6
  when nil   then [true,  :flags_unknown]
  when false then [false, :gated]
  else            [true,  :accepted]
  end
end

# Returns [selected_repos, warnings]
def select_repos(repos, source)
  opts = {
    include_globs:    source.fetch('include', nil) || ['*'],
    exclude_globs:    source.fetch('exclude', nil) || [],
    force_include:    source.fetch('force_include', nil) || [],
    include_topics:   source.fetch('include_topics', nil) || [],
    exclude_topics:   source.fetch('exclude_topics', nil) || ['puppetsync-ignore'],
    exclude_archived: source.fetch('exclude_archived', true),
  }

  verdicts = repos.map do |repo|
    kept, reason = verdict(repo, opts)
    { repo: repo, kept: kept, reason: reason }
  end
  names_with = ->(reason) { verdicts.select { |v| v[:reason] == reason }.map { |v| v[:repo]['name'] }.sort }

  warnings = []
  unknown_flags = names_with.call(:flags_unknown)
  unless unknown_flags.empty?
    warnings << "#{unknown_flags.size} repo(s) carry no has_issues/has_pull_requests fields, so the contributions " \
                "gate could not be applied and they were INCLUDED: #{unknown_flags.join(', ')}"
  end
  gated_out = names_with.call(:gated)
  unless gated_out.empty?
    warnings << "#{gated_out.size} repo(s) matching the include filters were excluded because issues or pull " \
                "requests are disabled (the mirror signal; force_include overrides it): #{gated_out.join(', ')}"
  end
  dead_forces = opts[:force_include].reject { |glob| repos.any? { |repo| File.fnmatch(glob, repo['name']) } }
  unless dead_forces.empty?
    warnings << "force_include glob(s) matched no repo in the org listing (typo?): #{dead_forces.join(', ')}"
  end

  [verdicts.select { |v| v[:kept] }.map { |v| v[:repo] }, warnings]
end

def repos_config(repos)
  repos.sort_by { |repo| repo['name'] }.each_with_object({}) do |repo, config|
    config["https://github.com/#{repo['full_name']}"] = { 'branch' => repo['default_branch'] }
  end
end

stdin = STDIN.read
params = JSON.parse(stdin)

source = params['source']
raise('No source given') unless source.is_a?(Hash)

validate_source!(source)

# `repos` bypasses the API for testing; normal runs fetch the org listing
repos = params['repos']
if repos.nil?
  org = source['org']
  raise('No org given in source') unless org

  repos = fetch_org_repos(org, params['github_authtoken'])
end

selected, warnings = select_repos(repos, source)
warnings.each { |w| warn "== WARNING: #{w}" }
warn "== selected #{selected.size} of #{repos.size} repos"
puts JSON.generate({ 'repos_config' => repos_config(selected), 'count' => selected.size, 'warnings' => warnings })
