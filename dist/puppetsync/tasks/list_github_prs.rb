#!/opt/puppetlabs/bolt/bin/ruby
#
# Enumerate a puppetsync session's open PRs from the GitHub API.
#
# The PRs themselves are the ground truth for the approve/merge plans: every
# repo the sync successfully pushed has exactly one open PR on the session's
# feature branch, so enumerating by head branch (and author) gives the exact
# work set — no inventory snapshot required, no drift when repos appear in
# or vanish from the org between sync and harvest.
#
# Each PR's base branch is hydrated with a follow-up request (the search API
# doesn't return it); transient failures are retried with backoff.

require 'json'
require 'net/http'
require 'uri'

PER_PAGE = 100

def request_json(uri, token, attempts: 3)
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

    JSON.parse(response.body)
  rescue Net::HTTPFatalError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    raise("ERROR: GitHub API request for #{uri.path} failed after #{attempts} attempts: #{e.message}") if attempt >= attempts

    warn "== retrying #{uri.path} after error (attempt #{attempt}/#{attempts}): #{e.message}"
    sleep(2 * attempt)
    retry
  end
end

def search_open_prs(org, head_branch, author, token)
  q = "is:pr is:open org:#{org} head:#{head_branch}"
  q += " author:#{author}" if author && !author.empty?
  items = []
  page = 1
  loop do
    uri = URI("https://api.github.com/search/issues?q=#{URI.encode_www_form_component(q)}&per_page=#{PER_PAGE}&page=#{page}")
    result = request_json(uri, token)
    items.concat(result['items'])
    break if items.size >= result['total_count'] || result['items'].empty?

    page += 1
  end
  items
end

def hydrate_prs(items, token)
  items.map do |item|
    repo = item['repository_url'].split('/repos/').last
    number = item['number']
    pull = request_json(URI("https://api.github.com/repos/#{repo}/pulls/#{number}"), token)
    { 'repo' => repo, 'number' => number, 'base' => pull['base']['ref'] }
  end
end

stdin = STDIN.read
params = JSON.parse(stdin)

# `prs` bypasses the API for testing; normal runs search GitHub
prs = params['prs']
if prs.nil?
  org = params['org']
  head_branch = params['head_branch']
  raise('No org given') unless org
  raise('No head_branch given') unless head_branch

  token = params['github_authtoken']
  items = search_open_prs(org, head_branch, params['author'], token)
  warn "== found #{items.size} open PRs on head branch '#{head_branch}' in org '#{org}'"
  prs = hydrate_prs(items, token)
end

prs = prs.sort_by { |pr| pr['repo'] }
puts JSON.generate({ 'prs' => prs, 'count' => prs.size })
