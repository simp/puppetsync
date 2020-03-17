require 'rubygems'
require 'puppetsync/script_helpers.rb'
include Puppetsync::ScriptHelpers

@repo_rel_path = Dir.pwd.sub(%r{^#{Facter.value(:puppetsync_src_dir)}#{File::SEPARATOR}},'')
@report_fact   = "report__#{@repo_rel_path.gsub(File::SEPARATOR,'_')}"
@repo_facts    = Facter.value(@report_fact)

require 'pry'; binding.pry
##exit 50 unless @repo_facts['git_changes']
fail('ABORTING FAILED REPO') if @repo_facts['is_failed']

# FIXME: do better
jira = repo_facts('jira_issues').fetch('jira_issues',{'jira_issues' => {} } )
require 'pry'; binding.pry
child = jira['SIMP-7035'].first
project = @repo_facts['repo']['git'].split('/')[-2..-1].join('/')

###gerrit_projects = Facter.value(:gerrit_data).select{|x| x['project'] == project }
###gerrit_change_id = nil
###gerrit_branch    = nil
###unless gerrit_projects.empty?
###  gerrit_project = gerrit_projects.first
###  if gerrit_project['open']
###    gerrit_change_id = gerrit_project['id']
###    gerrit_branch = gerrit_project['branch']
###  end
###end

component = Facter.value :repo_git_name
commit_msg = <<EOF
(SIMP-7035) Update to new Travis CI pipeline

This patch updates the Travis Pipeline to a static, standardized format
that uses project variables for secrets. It includes an optional
diagnostic mode to test the project's variables against their respective
deployment APIs (GitHub and Puppet Forge).

SIMP-7035 #comment Add new pipeline to #{component}
#{child} #close
EOF

_path = 'x'

stage_file('git_commit.msg') do |f,path|
  f.puts commit_msg
  # TODO: append gerrit here
  _path = path
  puts commit_msg
end

#shl ['git','rm','-f','Gemfile.lock'] if File.exists? 'Gemfile.lock'
shl ['git','add', '-A']
current_commit = `git log -1 --pretty=%B`.chomp


if current_commit == commit_msg
  shl ['git', 'commit', '-F', _path, '--amend']
else
  shl ['git', 'commit', '-F', _path]
end

# TODO: determine gerrit branch based on GitHub PR
# TODO github PR using octiokit and not hub
### if gerrit_change_id
###   # FIXME: HARDCODE
###   shl ['git', 'push', 'origin', 'SIMP-1868', '-f']
### end
