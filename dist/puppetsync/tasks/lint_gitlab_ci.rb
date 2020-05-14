#!/opt/puppetlabs/bolt/bin/ruby

require 'net/http'
require 'uri'
require 'json'
require 'yaml'

def gitlab_ci_lint(gitlab_ci_url, gitlab_ci_yml_path)
  unless File.exist? gitlab_ci_yml_path
    warn "WARNING: no GitLab CI config found at '#{gitlab_ci_yml_path}'"
    warn '(skipping)'
    return
  end

  uri = URI.parse(gitlab_ci_url)
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'

  content = YAML.load_file(gitlab_ci_yml_path)
  request.body = JSON.dump('content' => content.to_json)
  req_options = {
    use_ssl: uri.scheme == 'https',
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if response.code_type != Net::HTTPOK
    msg =  "ERROR: Could not use CI linter at #{gitlab_ci_url} " \
           "(#{response.code}: #{response.message})\n\n"

  elsif JSON.parse(response.body).fetch('status', '') != 'valid'
    msg =  "ERROR: #{File.basename(gitlab_ci_yml_path)} is not valid!\n\n"
    data = JSON.parse response.body
    data['errors'].each do |error|
      msg += "  * #{error}"
    end
    msg += "\n\n"
    msg += "Path: '#{gitlab_ci_yml_path}'\n"
  else
    puts "#{File.basename(gitlab_ci_yml_path)} is valid\n\n"
  end
  abort msg if msg
end

stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

files = params['repo_paths'].map { |x| File.join(x, '.gitlab-ci.yml') } || ARGV
raise('No repo_paths given') unless params['repo_paths'] && ARGV.empty?

files.each do |path|
  warn "\n\n#{path}"
  gitlab_ci_lint(
    'https://gitlab.com/api/v4/ci/lint',
    path,
  )
end
warn "FINIS: #{__FILE__}"
