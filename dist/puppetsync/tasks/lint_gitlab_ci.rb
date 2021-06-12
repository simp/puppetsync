#!/opt/puppetlabs/bolt/bin/ruby

require 'net/http'
require 'uri'
require 'open-uri'
require 'json'
require 'yaml'
require 'faraday'


def lint_request(gitlab_ci_url, gitlab_token, body)
  response = Faraday.post(gitlab_ci_url) do |req|
    req.params['limit'] = 100
    req.headers['Content-Type'] = 'application/json'
    req.headers['PRIVATE-TOKEN'] = gitlab_token
    #req.headers['Authorization'] = "Bearer #{gitlab_token}"
    req.body = body
  end
end

def err_msg_about_response(response, gitlab_ci_url, gitlab_ci_yml_path)
  unless response.success?
    return "ERROR: Could not use CI linter at #{gitlab_ci_url} (#{response.status} #{response.reason_phrase}):\n#{JSON.parse(response.body).to_yaml}\n\n"
  end
  if JSON.parse(response.body).fetch('status', '') != 'valid'
    msg =  "ERROR: #{File.basename(gitlab_ci_yml_path)} is not valid!\n\n"
    data = JSON.parse response.body
    data['errors'].each { |error| msg += "  * #{error}" }
    msg += "\n\n"
    msg += "Path: '#{gitlab_ci_yml_path}'\n"
    return(msg)
  end
end

def gitlab_ci_lint(gitlab_ci_url, gitlab_ci_yml_path, gitlab_token)
  unless File.exist? gitlab_ci_yml_path
    warn "WARNING: no GitLab CI config found at '#{gitlab_ci_yml_path}'"
    warn '(skipping)'
    return
  end

  content = YAML.load_file(gitlab_ci_yml_path)
  body = JSON.dump('content' => content.to_json)
  response = lint_request(gitlab_ci_url, gitlab_token, body)
  msg = err_msg_about_response(response, gitlab_ci_url, gitlab_ci_yml_path)
  msg ? abort(msg) : puts( "#{File.basename(gitlab_ci_yml_path)} is valid\n\n")
end

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  stdin = ''
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  require 'json'
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin) || {}
else
  params = {
    'repo_paths' => [ARGF.filename] + ARGV.to_a
  }
end

gitlab_token = params['gitlab_private_api_token'] || ENV['GITLAB_API_TOKEN']
files = (params['repo_paths'] || []).map { |x| File.join(x, '.gitlab-ci.yml') } || ARGV
warn "files", files
raise('No repo_paths given') if params.to_h['repo_paths'].to_a.empty?

files.each do |path|
  warn "\n\n#{path}"
  gitlab_ci_lint(
    'https://gitlab.com/api/v4/ci/lint',
    path,
    gitlab_token,
  )
end

warn "FINIS: #{__FILE__}"
