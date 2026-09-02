#!/opt/puppetlabs/bolt/bin/ruby
#
# Build a puppetsync repos_config hash dynamically from the GitHub API
# (simp/puppetsync#55), so repolists don't have to be hand-maintained.
#
# Filtering (all driven by the `source` parameter):
#
#   - Archived repos are excluded (`exclude_archived`, default true)
#   - Repos with issues OR pull requests DISABLED are excluded:
#     puppetsync's whole output is a PR, and the simp org disables
#     issues+PRs on every fork that exists only as a mirror — so either
#     flag being off separates mirrors from maintained repos (forks
#     included). (The old `exclude_forks`/`include_forks` allow-list is
#     retired.)
#   - Repos with any topic in `exclude_topics` are excluded (default:
#     ['puppetsync-ignore'] — set that topic on a repo in GitHub to opt it
#     out without touching puppetsync)
#   - The repo name must match an `include` glob, or the repo must have a
#     topic in `include_topics` (defaults: ['*'] / none)
#   - Repos matching an `exclude` glob are always excluded
#   - Empty repos (size 0) are excluded — there is nothing to clone
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

def glob_match?(name, globs)
  globs.any? { |glob| File.fnmatch(glob, name) }
end

def select_repos(repos, source)
  include_globs    = source.fetch('include', nil) || ['*']
  exclude_globs    = source.fetch('exclude', nil) || []
  include_topics   = source.fetch('include_topics', nil) || []
  exclude_topics   = source.fetch('exclude_topics', nil) || ['puppetsync-ignore']
  exclude_archived = source.fetch('exclude_archived', true)
  if source.key?('exclude_forks') || source.key?('include_forks')
    warn '== WARNING: exclude_forks/include_forks are retired and ignored — ' \
         'inventory now includes any repo with issues+PRs enabled ' \
         '(mirrors have them disabled org-wide)'
  end

  repos.select do |repo|
    name = repo['name']
    topics = repo['topics'] || []
    next false if exclude_archived && repo['archived']
    next false if repo['size'].to_i.zero?
    # puppetsync's whole output is a PR; a repo with PRs (or issues)
    # disabled is a mirror (the org turns both off on mirror forks).
    # Absent fields => include, so older API responses/fixtures don't
    # silently empty the inventory.
    next false unless repo.fetch('has_pull_requests', true) && repo.fetch('has_issues', true)
    next false if glob_match?(name, exclude_globs)
    next false if topics.any? { |topic| exclude_topics.include?(topic) }

    glob_match?(name, include_globs) || topics.any? { |topic| include_topics.include?(topic) }
  end
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

# `repos` bypasses the API for testing; normal runs fetch the org listing
repos = params['repos']
if repos.nil?
  org = source['org']
  raise("No org given in source") unless org

  repos = fetch_org_repos(org, params['github_authtoken'])
end

selected = select_repos(repos, source)
warn "== selected #{selected.size} of #{repos.size} repos"
puts JSON.generate({ 'repos_config' => repos_config(selected), 'count' => selected.size })
