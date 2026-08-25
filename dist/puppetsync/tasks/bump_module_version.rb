#!/opt/puppetlabs/bolt/bin/ruby
# frozen_string_literal: true

# Bump a module's version in metadata.json and prepend a matching
# RPM-style CHANGELOG entry — the release-engineering follow-through for
# any pipeline stage that changes release artifacts (RELENG's
# pkg:compare_latest_tag fails a PR whose content changed without a
# version bump).
#
# Self-gating: a repo whose working tree is CLEAN is skipped, so this
# stage can run after any mutating stage and only touches repos that
# actually changed. Everything the old modernize_metadata_json
# bump_version hardcoded (author, email, changelog message) is a
# parameter (simp/puppetsync#68).

require 'json'
require 'open3'
require 'time'

def rpm_changelog_entry(version, author, email, message)
  lines = message.split("\n").map do |line|
    line.start_with?('-', ' ') ? line : "- #{line}"
  end
  format("* %s %s <%s> - %s\n%s\n", Time.now.strftime('%a %b %d %Y'), author, email, version, lines.join("\n"))
end

def bump_version(version, bump)
  parts = version.split('.').map(&:to_i)
  case bump
  when 'minor' then parts[1] += 1; parts[2] = 0
  when 'patch' then parts[2] += 1
  else raise("Unknown bump type '#{bump}' (expected 'patch' or 'minor')")
  end
  parts.join('.')
end

stdin = STDIN.read
params = JSON.parse(stdin)

repo_path = params['repo_path']
raise('No repo_path given') unless repo_path
%w[changelog_message author email].each do |key|
  raise("No #{key} given") if params[key].to_s.empty?
end
bump = params['bump'] || 'patch'

status_out, status = Open3.capture2e('git', '-C', repo_path, 'status', '--porcelain')
raise("git status failed in #{repo_path}: #{status_out}") unless status.success?
if status_out.strip.empty?
  puts JSON.generate({ 'changed' => false, 'skip' => 'working tree clean — nothing to release' })
  exit 0
end

metadata_path = File.join(repo_path, 'metadata.json')
raise("No metadata.json in #{repo_path}") unless File.exist?(metadata_path)

changelog_path = File.join(repo_path, 'CHANGELOG')
unless File.exist?(changelog_path)
  # Without a CHANGELOG we can't produce a releasable state (RELENG's
  # pkg:create_tag_changelog needs the entry), so leave the version alone
  # and let the repo surface in the results
  puts JSON.generate({ 'changed' => false, 'skip' => 'no CHANGELOG file — version bump withheld' })
  exit 0
end

metadata = JSON.parse(File.read(metadata_path))
old_version = metadata['version']
unless old_version =~ /\A\d+\.\d+\.\d+\z/
  puts JSON.generate({ 'changed' => false, 'skip' => "version '#{old_version}' is not plain X.Y.Z — bump withheld" })
  exit 0
end

new_version = bump_version(old_version, bump)
metadata['version'] = new_version
File.write(metadata_path, JSON.pretty_generate(metadata) + "\n")

entry = rpm_changelog_entry(new_version, params['author'], params['email'], params['changelog_message'])
File.write(changelog_path, entry + "\n" + File.read(changelog_path))

puts JSON.generate({ 'changed' => true, 'from' => old_version, 'to' => new_version })
