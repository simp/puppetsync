require 'rubygems'
require 'jira-ruby'

# - Ensure that a Jira subtask exists for this component + parent
# - Leave a record of the subtask's issue number.

# TODO: upfront rejection criteria:
#  - not the right condition (based on some other fact?)
#     - based on some other fact?
#     - this should be a global skip criteria
#  - don't creat a subtask if a subtask already exists
#     - but either way, record the child issue number

require 'facter'
ENV.fetch('FACTERLIB','').split(':').each{|x| Facter.search x }


# TODO: write these somewhere so the git message:
# - issue number
# - parent issue number

options = {
  :username     => ENV['JIRA_USER'],
  :password     => ENV['JIRA_API_TOKEN'],
  :site         => ENV['JIRA_SITE'] || 'https://simp-project.atlassian.net/',
  :context_path => '',
  :auth_type    => :basic,
  :http_debug => true,
#  :read_timeout => 120,
#  :use_ssl      => true,
}

require 'pp'
_c = Facter['repo_git_name'].value
puts _c
pp options
puts 'x1'
client = JIRA::Client.new(options)

puts 'x2'
project_name  = ENV['JIRA_PROJECT'] || 'SIMP'
parent_ticket = 'SIMP-7035' # FIXME: argument
child_summary = "Update Travis CI pipeline in COMPONENT"
assignee      = ENV['JIRA_ASSIGNEE'] || options.fetch(:username).sub(/@.*$/,'')

puts 'x3'

project = client.Project.find( project_name )
components = project.components
component_keys = components.map{|x| x.name }

fail("FATAL: could not find component for '#{_c}' in Jira") unless component_keys.include?(_c)

# make a new subtask issue unless:
#  - there is already an open subtask for the component under that parent
#
# assumptions:
#  - there will only have one subtask per componenet per parent issue
#
# risks:
#  - Jira supports more than one component ber issue/subtask
_jql = "project = #{project_name} " +
  " AND parent = #{parent_ticket}" +
  " AND component = #{_c}" +
  " AND statuscategory != done" +
  " AND statuscategory != undefined"
subtasks = client.Issue.jql( _jql )

parent_issue_object = client.Issue.find(parent_ticket)
# id 5 is 'SubTask' in our Jira
# TODO: more robust / less magic numbers, please
subtask_issuetype = client.Issuetype.all.select{|x| x.name == 'Sub-task' }.first.id

child_issue_number = nil
data = {
  'fields' => {
    'summary'   => child_summary.sub('COMPONENT',_c),
    'project'   =>  { 'key'=> project_name },
    'parent'    =>  { 'key'=> parent_ticket },
    'issuetype'  => { "id" => subtask_issuetype },
    'components' => [{'name' => _c }],
  }
}
data['fields']['assignee'] = { 'name' => assignee } if assignee

if subtasks.size == 0
  begin
  issue = client.Issue.build data
  issue.save data
  issue.fetch
  child_issue_number = issue.key
  rescue JIRA::HTTPError => e
    require 'yaml'
    puts e.to_yaml
    require 'pry'; binding.pry
  end
else
  ###   # smash existing subtask into our own image (not recommended)
  ###   issue = subtasks.first
  ###   issue.save data
  ###   issue.fetch
  ###   child_issue_number = issue.key
  child_issue_number = subtasks.first.key
end
puts "%%% JIRA CHILD ISSUE Number = #{child_issue_number}"
# TODO: record child
