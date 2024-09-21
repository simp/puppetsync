#!/opt/puppetlabs/bolt/bin/ruby
require 'fileutils'
require 'json'

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  require 'json'
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  file = params['file']
else
  file = ARGF.filename
end

# Read content from metadata.json file
warn "file: '#{file}'"
raise('No metadata.json path given') unless file
dir = File.dirname(file)
content = File.read(file)
data = JSON.parse(content)
el_oses = ['CentOS', 'RedHat', 'OracleLinux', 'Amazon', 'Scientific']
oses = (data['operatingsystem_support'] || []).select { |os| el_oses.include?(os['operatingsystem']) }
changes = oses.map { |os| os['operatingsystemrelease'].delete('6') }
changes.compact!

new_version = nil
# bump Z version if changed
unless changes.empty?
  parts = data['version'].split(%r{[\.-]})
  parts[2] = (parts[2].to_i + 1).to_s
  new_version = parts.join('.')
  data['version'] = new_version
end

File.open(file, 'w') { |f| f.puts(JSON.pretty_generate(data)) }
warn "\n\n++ processed '#{file}'"

if new_version
  changelog_file = File.join(dir, 'CHANGELOG')
  changelog = File.read(changelog_file)
  require 'date'
  new_lines = []
  new_lines << DateTime.now.strftime("* %a %b %d %Y Chris Tessmer <chris.tessmer@onyxpoint.com> - #{new_version}")
  new_lines << '- Removed EL6 from supported OSes'
  changelog = new_lines.join("\n") + "\n\n" + changelog
  File.open(changelog_file, 'w') { |f| f.puts changelog }
end

# Remove el6 nodesets
warn(`find $(find #{dir}/spec/acceptance -name nodesets -type d) -name centos-6.yml -print -exec rm -f {} \\; &> /dev/null`)

# Remove el6 YAML files
warn(`find #{dir}/data/os -name \*6.yaml -print -exec rm -f {} \\; &>/dev/null`)

# Remove el6 hosts from Beaker nodesets
nodeset_files = `find $(find #{dir}/spec/acceptance -name nodesets -type d) -name \\*.yml`.split("\n")
warn `grep -E 'el.?6' #{nodeset_files.join(' ')}`
nodeset_files.each do |nodeset_file|
  next if `grep -c  '^ *platform: *el-6-x86_64' #{nodeset_file}`.strip == '0'
  d = File.read(nodeset_file)
  section_start_line = nil
  delete_block = false
  ranges_to_delete = []
  d.lines.each_with_index do |line, idx|
    if section_start_line && (line =~ %r{^ {0,2}[a-zA-Z<]} || idx == (d.lines.size - 1)) && delete_block
      i = idx - 1
      i = idx if idx == (d.lines.size - 1)
      ranges_to_delete << (section_start_line..i)
      warn "DELETE BLOCK (starts at #{section_start_line}, ends at #{idx})"
      delete_block = false
      section_start_line = nil
    end
    if %r{^  [a-z].*:$}.match?(line)
      warn "NEW BLOCK: '#{line.strip}'"
      section_start_line = idx
      delete_block = false
    end
    if %r{^    platform: *el-6-x86_64}.match?(line)
      delete_block = true
      warn "FOUND BAD BLOCK (starts at #{section_start_line})"
    end
  end

  lines = d.lines
  ranges_to_delete.reverse_each { |r| lines.slice!(r) }
  lines_str = lines.join

  # HACK: Migrate any now-missing roles from deleted nodes to the first node with roles
  roles_regex = %r{^ *(?<host>[a-z0-9_-]+):\n  *roles:(?<roles>(?:\n *- [a-z0-9-]+)*)}
  orig_roles = d.scan(roles_regex).map { |x| [x[0], x[1].split(%r{\n *- }).reject { |y| y.empty? }] }.to_h
  new_roles = lines_str.scan(roles_regex).map { |x| [x[0], x[1].split(%r{\n *- }).reject { |y| y.empty? }] }.to_h
  deleted_nodes = (orig_roles.keys - new_roles.keys)
  deleted_node_roles = deleted_nodes.map { |x| orig_roles[x] }.flatten.uniq
  new_node_roles = new_roles.map { |_k, x| x }.flatten.uniq
  missing_roles = deleted_node_roles - new_node_roles
  missing_roles.reject! { |x| x.match(%r{[-_]?(el|rhel|oel|centos)[-_]?6$}) }
  unless missing_roles.empty?
    role_subs = 0
    lines_str.sub!(%r{^ *roles:\n(?<space> *- )(?<role>[a-z0-9-]+)}) do |s|
      role_subs += 1
      space = s.match(%r{^ *roles:\n(?<space> *- )(?<role>[a-z0-9-]+)})[:space]
      s + "\n" + space.sub('- ', '# roles migrated from now-removed el6 node(s):') + missing_roles.map { |x| "\n#{space}#{x}" }.join
    end
    if role_subs == 0 # if no other nodeset contained roles
      space = lines_str.sub!(%r{^(?<space> *)platform:.*$}) do |s|
        space = s.match(%r{^(?<space> *)platform:})[:space]
        "#{space}roles: # migrated from now-removed el6 node(s)" + missing_roles.map { |x| "\n#{space}- #{x}" }.join + "\n#{s}"
      end
    end
  end

  File.open(nodeset_file, 'w') { |f| f.puts lines_str }
end

# rubocop:disable Layout/LineLength
warn %@grep -i -r -e "\\['6', \\?'7'\\|facts\\(\\['os'\\]\\['release'\\]\\['major'\\]\\|\\[:operatingsystemmajrelease\\]\\|\\[:os\\]\\[:release\\]\\[:major\\]\\)\\(\\.to_\\(i\\|\\s\\)\\)\\? \\(\\(<=\\|==\\) '\\?6'\\?\\|< '\\?7'\\?\\)\\|\\['\\?6'\\?, ?'\\?7'\\?\\]\\|\\(oel\\|rhel\\|centos\\|el\\).6\\|versioncmp($facts\\['os'\\]\\['release'\\]\\['major'\\], '6')" --exclude-dir=.{plan.gems,gems,git} --exclude=\\* --include=\\*.{rb,pp,erb,epp} '#{dir}'@
grep_results = `grep -i -r -e "\\['6', \\?'7'\\|facts\\(\\['os'\\]\\['release'\\]\\['major'\\]\\|\\[:operatingsystemmajrelease\\]\\|\\[:os\\]\\[:release\\]\\[:major\\]\\)\\(\\.to_\\(i\\|\\s\\)\\)\\? \\(\\(<=\\|==\\) '\\?6'\\?\\|< '\\?7'\\?\\)\\|\\['\\?6'\\?, ?'\\?7'\\?\\]\\|\\(oel\\|rhel\\|centos\\|el\\).6\\|versioncmp($facts\\['os'\\]\\['release'\\]\\['major'\\], '6')" --exclude-dir=.{plan.gems,gems,git} --exclude=\\* --include=\\*.{rb,pp,erb,epp} '#{dir}'`
# rubocop:enable Layout/LineLength

unless grep_results.empty?
  raise "ERROR: EL6 detritus detected under #{dir}:\n\n #{grep_results}\n\n"
end

warn "\n\nFINIS: #{__FILE__}"
