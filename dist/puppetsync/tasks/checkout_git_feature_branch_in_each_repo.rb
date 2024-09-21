require 'json'
require 'English'

def checkout_modules_to_branch(branch, repo_paths)
  results = {}
  mx = repo_paths.map { |x| File.basename(x).size }.max
  repo_paths.each do |dir|
    status = 'created'
    Dir.chdir dir
    warn "== #{dir}"
    `git branch --contains #{branch} &> /dev/null`
    if $CHILD_STATUS.success?
      status = 'checked_out'
      warn "NOTICE: branch '#{branch}' already exists; checking it out"
      pid = spawn 'git', 'checkout', branch, '-q'
    else
      warn "NOTICE: creating branch '#{branch}'"
      pid = spawn 'git', 'checkout', '-b', branch, '-q'
    end
    Process.wait pid
    if $CHILD_STATUS.success?
      warn "== #{File.basename(dir).ljust(mx)} : checked out git branch '#{branch}' in #{dir}"
      results[dir] = status
    else
      warn "== SOMETHING FED UP in #{dir}"
      results[dir] = false
    end
  end
  results
end

stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

raise('No branch given') unless params['branch']
raise('No repo paths given') unless params['repo_paths']
raise('No repo paths given (empty array)') if params['repo_paths'].empty?

results = checkout_modules_to_branch(params['branch'], params['repo_paths'])
raise('All git feature branch checkouts failed') unless results.any? { |_k, v| v }

puts JSON.pretty_generate(results)
