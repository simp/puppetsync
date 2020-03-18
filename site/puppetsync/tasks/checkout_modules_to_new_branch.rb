require 'json'

def checkout_modules_to_branch(branch, repo_paths)
  mx = repo_paths.map{|x| File.basename(x).size }.max
  repo_paths.each do |dir|
    Dir.chdir dir
    STDERR.puts "== #{dir}"
    `git branch --contains #{branch} &> /dev/null`
    if $?.success?
      warn "NOTICE: branch '#{branch}' already exists; checking it out"
      pid = spawn 'git','checkout',branch
      Process.wait pid
    else
      pid = spawn 'git','checkout','-b',branch
      Process.wait pid
    end
    if $?.success?
      puts "== #{File.basename(dir).ljust(mx)} : checked out git branch '#{branch}' in #{dir}"
    end
  end
end

stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

fail("No branch given") unless params['branch']
fail("No repo paths given") unless params['repo_paths']
checkout_modules_to_branch(params['branch'], params['repo_paths'])

