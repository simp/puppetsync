#!/opt/puppetlabs/bolt/bin/ruby
#
# Regenerate a Puppet module's REFERENCE.md from its strings docs:
#
#   bundle install && bundle exec rake strings:generate:reference
#
# Gems install into a bundle path shared across repos (default:
# <repo>/../../.vendor/bundle, i.e. the puppetsync project's .vendor) so a
# fleet run only downloads each gem once. The commit belongs to the
# git_commit_changes stage, like every other transformation — this task
# only changes the working tree and reports whether REFERENCE.md moved.
#
# With only_changed (how the plan runs it when a session doesn't list the
# stage), a repo is left alone unless it already has a REFERENCE.md and an
# earlier stage left changes in the working tree.

require 'json'
require 'open3'

BUNDLER_EXE = ENV['BUNDLER_EXE'] || '/opt/puppetlabs/bolt/bin/bundle'

def run(cmd, chdir:, env: {})
  out, status = Open3.capture2e(env, *cmd, chdir: chdir)
  raise("ERROR: '#{cmd.join(' ')}' failed in #{chdir}:\n#{out[-2000..] || out}") unless status.success?

  out
end

def skip_reason(repo_path)
  return 'no REFERENCE.md' unless File.exist?(File.join(repo_path, 'REFERENCE.md'))

  status_out, = Open3.capture2e('git', '-C', repo_path, 'status', '--porcelain')
  return 'no other changes' if status_out.strip.empty?

  nil
end

def generate_reference(repo_path, bundle_path)
  require 'bundler'
  Bundler.with_unbundled_env do
    env = { 'BUNDLE_PATH' => bundle_path, 'BUNDLE_JOBS' => '4' }
    run([BUNDLER_EXE, 'install', '--quiet'], chdir: repo_path, env: env)
    run([BUNDLER_EXE, 'exec', 'rake', 'strings:generate:reference'], chdir: repo_path, env: env)
  end

  raise("ERROR: no REFERENCE.md at #{repo_path} after strings:generate:reference") \
    unless File.exist?(File.join(repo_path, 'REFERENCE.md'))

  status_out, = Open3.capture2e('git', '-C', repo_path, 'status', '--porcelain', '--', 'REFERENCE.md')
  { 'changed' => !status_out.strip.empty? }
end

stdin = STDIN.read
params = JSON.parse(stdin)

repo_path = params['repo_path']
raise('No repo_path given') unless repo_path

if params['only_changed'] && (reason = skip_reason(repo_path))
  puts JSON.generate({ 'changed' => false, 'skipped' => reason })
  exit 0
end

bundle_path = params['bundle_path'] || File.expand_path(File.join(repo_path, '..', '..', '.vendor', 'bundle'))

puts JSON.generate(generate_reference(repo_path, bundle_path))
