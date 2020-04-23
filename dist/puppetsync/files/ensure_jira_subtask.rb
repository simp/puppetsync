require 'json'
class JiraHelper
  def initialize(
    username     = ENV['JIRA_USER'],
    api_token    = ENV['JIRA_API_TOKEN'],
    site         = ENV['JIRA_SITE'] || 'https://simp-project.atlassian.net/',
    context_path = '',
    auth_type    = :basic,
    http_debug   = ENV.fetch('JIRA_DEBUG','no') == 'yes'
  )
    @options = {
      username:     username,   # :username is probably an email address
      password:     api_token,  # password should be the Jira API token
      site:         site,
      context_path: context_path,
      auth_type:    auth_type,
      http_debug:   http_debug,
      rest_base_path:  '/rest/api/3',
    }
    require 'jira-ruby'
    @client = JIRA::Client.new(@options.dup)
  end


  def ensure_subtask(project_string, parent_issue_string, component_name, subtask_opts={})
    project               = @client.Project.find(project_string)
    parent_issue          = @client.Issue.find(parent_issue_string)
    story_points_field_id = custom_field_id(/^story points/i)
    subtask_issuetype_id  = issuetype_id(/^Sub-task/i)

    st_summary      = subtask_opts[:subtask_title].gsub('%COMPONENT%', component_name)
    st_description  = subtask_opts[:subtask_description] ? subtask_opts[:subtask_description].gsub('%COMPONENT%', component_name) : nil
    st_story_points = subtask_opts[:subtask_story_points] ? subtask_opts[:subtask_story_points] : nil

    component = project.components.select{|x| x.name == component_name }
    fail("FATAL: could not find component for '#{component_name}' in Jira project '#{project_string}'") if component.empty?
    component = component.first

    existing_subtasks_for_target = undone_target_component_subtasks( project_string, parent_issue_string, component_name)

    target_subtask_issue_key = nil
    data = {
      'fields' => {
        'summary'   => st_summary.to_s,
        'project'   =>  { 'id'=> project.id },
        'parent'    =>  { 'id'=> parent_issue.id },
        'issuetype'  => { 'id' => subtask_issuetype_id },
        'components' => [{'id' => component.id }],
      }
    }
    ###    data['fields']['description'] = st_description if st_description
    data['fields'][story_points_field_id] = st_story_points.to_f if st_story_points
    unless existing_subtasks_for_target.empty?
      data['key'] = existing_subtasks_for_target.first.attrs['key']
      data['id'] = existing_subtasks_for_target.first.attrs['id']
    end

    if existing_subtasks_for_target.empty? || true
      begin
        issue = @client.Issue.build data
        issue.save! data
        if subtask_opts[:subtask_assignee]
           st_assignee = @client.User.myself.attrs['accountId']
           issue.save( {'fields' => {'assignee' => { 'accountId' => st_assignee }}} )
        end
      rescue JIRA::HTTPError => e
        require 'yaml'
        warn e.to_yaml
        require 'pry'
        binding.irb
        raise e
      end
      issue.fetch
      target_subtask_issue_key = issue.key
    else
      target_subtask_issue_key = existing_subtasks_for_target.first.key
    end

    return target_subtask_issue_key

  end

  private


  def undone_target_component_subtasks(project_string, parent_issue_string, component_name)
    # make a new subtask issue unless:
    #  - there is already an open subtask for the component under that parent
    #
    # assumptions:
    #  - there will only have one subtask per componenet per parent issue
    #
    # risks:
    #  - Jira supports more than one component ber issue/subtask
    _jql = "project = #{project_string} " +
      " AND parent = #{parent_issue_string}" +
      " AND component = #{component_name}" +
      " AND statuscategory != done" +    # FIXME: remains to be seen if this is necessary
      " AND statuscategory != undefined"
    @client.Issue.jql( _jql )
  end
  # @param [JIRA::Client] client
  # @param [String] Jira issue key (e.g., `SIMP-1234`)
  # @return [Array<JIRA::Resource::Issue>] Array of subtask data
  def subtasks_of(issue_key)
    subtasks_keys = @client.Issue.find(issue_key).subtasks.map{ |x| x['key'] }
    subtasks_keys.map do |subtask_key|
      puts "== loading #{subtask_key}"
      @client.Issue.find(subtask_key)
    end
  end

  # @param [JIRA::Client] client
  # @param [Regexp] regex
  # @return [String] custom field id
  def custom_field_id(regex=/^story points/i)
    matching_fields = @client.Field.all.select{|x| x.name =~ regex}
    fail ("ERROR: No fields that match #{regex.to_s}") if matching_fields.size == 0
    if matching_fields.size > 1
      fail (
        "ERROR: Too many fields that match #{regex.to_s} " +
        "(got #{matching_fields.size}, expected 1): \n\n" +
        matching_fields.to_yaml
      )
    end
    matching_fields.first.id
  end

  def issuetype_id(regex=/^Sub-task/)
    matching_fields = @client.Issuetype.all.select{|x| x.name =~ regex }
    fail ("ERROR: No issuetypes that match #{regex.to_s}") if matching_fields.size == 0
    if matching_fields.size > 1
      fail (
        "ERROR: Too many fields that match #{regex.to_s} " +
        "(got #{matching_fields.size}, expected 1): \n\n" +
        matching_fields.to_yaml
      )
    end
    matching_fields.first.id
  end
end


if __FILE__ == $0
  kwargs = JSON.parse(File.read('x.json'))
  api = JiraHelper.new(
    ENV['JIRA_USER'],
    ENV['JIRA_API_TOKEN'],
    kwargs[:jira_site.to_s],
  )

  opts = kwargs.select{|k,v| k.to_s =~ /^subtask_/}

  # TODO: optional labels []
  subtask_key = api.ensure_subtask(
    kwargs[:project.to_s] || 'SIMP',
    kwargs[:parent_issue.to_s],
    kwargs[:component_name.to_s],
    Hash[opts.map{|k,v| [k.to_sym,v] }]
  )
  require 'pry'; binding.pry
end
