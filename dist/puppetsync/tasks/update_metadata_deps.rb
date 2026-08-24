#!/opt/puppetlabs/bolt/bin/ruby
# frozen_string_literal: true

# Update every repo's metadata.json dependencies from the Puppet Forge
# (simp/puppetsync#68)
#
# Runs ONCE over all repo paths so the Forge API is queried a single time
# per unique module slug (plus supersede-chain hops), no matter how many
# repos reference it. For each dependency (including
# simp.optional_dependencies):
#
#   * follows `superseded_by` chains and renames moved/deprecated modules
#   * when the module's current release falls outside the existing
#     two-bound version_requirement, bumps the UPPER bound to
#     `< <next major>` (the lower bound is never touched)
#   * leaves in-range requirements untouched; warns and skips
#     requirements that are not a clean two-bound range
#
# Only semantic changes are written (JSON.pretty_generate, so a repo with
# unusual metadata.json formatting is canonicalized when — and only
# when — it has a real update). Committing is git_commit_changes' job.
#
# Derived from https://github.com/silug/puppet-tools/blob/master/update-metadata

require 'json'
require 'net/http'
require 'uri'

DEFAULT_FORGE_API = 'https://forgeapi.puppet.com/v3'
USER_AGENT = 'puppetsync (+https://github.com/simp/puppetsync)'

class ForgeResolver
  attr_reader :request_count

  def initialize(api_url)
    @api_url = api_url.chomp('/')
    @cache = {}
    @request_count = 0
  end

  # slug -> {'slug' =>, 'version' =>} for the END of any superseded_by
  # chain, nil when unresolvable. Every chain hop is cached.
  def resolve(slug)
    return @cache[slug] if @cache.key?(slug)

    info = get_json("#{@api_url}/modules/#{slug}")
    if info.nil?
      @cache[slug] = nil
    elsif info['superseded_by']
      successor = info['superseded_by']['slug']
      warn "  => #{slug} superseded by #{successor}"
      @cache[slug] = resolve(successor)
    else
      @cache[slug] = {
        'slug'    => info['slug'],
        'version' => info.dig('current_release', 'version'),
      }
    end
    @cache[slug]
  end

  private

  def get_json(url, redirects_left = 3)
    @request_count += 1
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT
      http.request(request)
    end
    case response
    when Net::HTTPSuccess then JSON.parse(response.body)
    when Net::HTTPRedirection
      raise "Too many redirects for #{url}" unless redirects_left.positive?
      get_json(response['location'], redirects_left - 1)
    else
      warn "  !! #{url}: HTTP #{response.code}"
      nil
    end
  rescue StandardError => e
    warn "  !! #{url}: #{e.message}"
    nil
  end
end

def nextmajor(current_version)
  parts = current_version.split('.').map(&:to_i)
  parts[0] += 1
  (1...parts.length).each { |i| parts[i] = 0 }
  parts.join('.')
end

# Mutates dep in place; returns a change record, a skip record, or nil
def process_dependency(dep, resolver)
  return nil unless dep.is_a?(Hash) && dep.key?('name')

  slug = dep['name'].tr('/', '-')
  info = resolver.resolve(slug)
  return { 'skip' => "#{slug}: not resolvable on the Forge" } if info.nil? || info['version'].nil?

  change = {}
  if info['slug'] != slug
    # Preserve the repo's separator style ('owner/module' vs 'owner-module');
    # a Forge slug's first dash is always the owner/module separator
    new_name = dep['name'].include?('/') ? info['slug'].sub('-', '/') : info['slug']
    change['renamed'] = { 'from' => dep['name'], 'to' => new_name }
    dep['name'] = new_name
  end

  if dep.key?('version_requirement')
    current = Gem::Version.new(info['version'])
    bounds = dep['version_requirement'].split(%r{\s+(?=[<>=~])}, 2)
    unless Gem::Requirement.new(bounds).satisfied_by?(current)
      if bounds.length == 2
        old_requirement = dep['version_requirement']
        bounds[1] = "< #{nextmajor(info['version'])}"
        if Gem::Requirement.new(bounds).satisfied_by?(current)
          dep['version_requirement'] = bounds.join(' ')
          change['requirement'] = { 'from' => old_requirement, 'to' => dep['version_requirement'] }
        else
          return { 'skip' => "#{info['slug']}: no matching range for #{info['version']} (tried #{bounds.inspect})" }
        end
      else
        return { 'skip' => "#{info['slug']}: #{info['version']} out of range, but '#{dep['version_requirement']}' is not a two-bound range" }
      end
    end
  end

  change.empty? ? nil : change
end

def process_repo(repo_path, resolver)
  metadata_path = File.join(repo_path, 'metadata.json')
  return { 'changed' => false, 'skip' => 'no metadata.json' } unless File.exist?(metadata_path)

  original = File.read(metadata_path)
  metadata = JSON.parse(original)
  updates = []
  skips = []

  dep_lists = [metadata['dependencies'], metadata.dig('simp', 'optional_dependencies')].compact
  dep_lists.each do |deps|
    deps.each do |dep|
      warn "Checking #{File.basename(repo_path)}: #{dep['name']} #{dep['version_requirement']}"
      result = process_dependency(dep, resolver)
      next if result.nil?

      result.key?('skip') ? skips << result['skip'] : updates << result
    end
  end

  changed = !updates.empty?
  File.write(metadata_path, JSON.pretty_generate(metadata) + "\n") if changed
  { 'changed' => changed, 'updates' => updates, 'skips' => skips }
end

stdin = STDIN.read
params = JSON.parse(stdin)

repo_paths = params['repo_paths']
raise('No repo_paths given') unless repo_paths.is_a?(Array) && !repo_paths.empty?

resolver = ForgeResolver.new(params['forge_api_url'] || DEFAULT_FORGE_API)

repos = {}
repo_paths.each do |repo_path|
  repos[File.basename(repo_path)] = process_repo(repo_path, resolver)
end

puts JSON.generate({
  'changed'        => repos.values.any? { |r| r['changed'] },
  'forge_requests' => resolver.request_count,
  'repos'          => repos,
})
