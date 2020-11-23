#!/opt/puppetlabs/bolt/bin/ruby

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  # running under bolt
  stdin = ''
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  require 'json'
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  url = params['template_url']
  ref = params['template_ref']
  repo_path = params['repo_path']
else
  repo_path = ARGV[1]
  url = ARGV[2]
  ref = ARGV[3]
end

system("cd '#{repo_path}'; pdk convert --force --template-url '#{url}' --template-ref '#{ref}'")
