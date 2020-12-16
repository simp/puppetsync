#!/opt/puppetlabs/bolt/bin/ruby
require 'fileutils'
require 'json'

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  stdin = ''
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
content = File.read(file)
data = JSON.parse(content)
el_oses = ['CentOS', 'RedHat', 'OracleLinux', 'Amazon', 'Scientific']
oses = data['operatingsystem_support'].select{ |os| el_oses.include?(os['operatingsystem']) }
oses.each{|os| os['operatingsystemrelease'].delete('6') }
File.open(file,'w'){|f| f.puts(JSON.pretty_generate(data)) }
warn "\n\n++ processed '#{file}'"



dir = File.dirname(file)

# Remove el6 nodesets
warn( %x[find $(find #{dir}/spec/acceptance -name nodesets -type d) -name centos-6.yml -print -exec rm -f {} \\; &> /dev/null] )

# Remove el6 YAML files
warn( %x[find #{dir}/data/os -name \*6.yaml -print -exec rm -f {} \\; &>/dev/null] )

# Remove el6 hosts from Beaker nodesets
nodeset_files = %x[find $(find #{dir}/spec/acceptance -name nodesets -type d) -name \*.yml].split("\n")
warn %x[grep -E 'el.?6' #{nodeset_files.join(" ")}]
nodeset_files.each do |nodeset_file|
  next if %x[grep -c  '^ *platform: *el-6-x86_64' #{nodeset_file}].strip == '0'
  d = File.read(nodeset_file)
  section_start_line=nil
  delete_block=false
  ranges_to_delete = []
  d.lines.each_with_index do |line,idx|
    if section_start_line && (line =~ /^ {0,2}[a-zA-Z<]/ || idx == (d.lines.size-1)) && delete_block
      i = idx-1
      i = idx if idx == (d.lines.size-1)
      ranges_to_delete << (section_start_line..i)
      warn "DELETE BLOCK (starts at #{section_start_line}, ends at #{idx})"
      delete_block=false
      section_start_line=nil
    end
    if line =~ /^  [a-z].*:$/
      warn "NEW BLOCK: '#{line.strip}'"
      section_start_line=idx
      delete_block=false
    end
    if line =~ /^    platform: *el-6-x86_64/
      delete_block = true
      warn "FOUND BAD BLOCK (starts at #{section_start_line})"
    end
  end

  lines = d.lines
  ranges_to_delete.reverse.each { |r| lines.slice!(r) }
  File.open(nodeset_file,'w'){|f| f.puts lines.join}
end

warn %Q@grep -i -r -e "\\['6', \\?'7'\\|facts\\(\\['os'\\]\\['release'\\]\\['major'\\]\\|\\[:operatingsystemmajrelease\\]\\|\\[:os\\]\\[:release\\]\\[:major\\]\\)\\(\\.to_\\(i\\|\\s\\)\\)\\? \\(\\(<=\\|==\\) '\\?6'\\?\\|< '\\?7'\\?\\)\\|\\['\\?6'\\?, ?'\\?7'\\?\\]\\|\\(oel\\|rhel\\|centos\\|el\\).6\\|versioncmp($facts\\['os'\\]\\['release'\\]\\['major'\\], '6')" '#{dir}' --exclude-dir=.{plan.gems,gems,git} --exclude=\\* --include=\\*.{rb,pp}@
grep_results = %x@grep -i -r -e "\\['6', \\?'7'\\|facts\\(\\['os'\\]\\['release'\\]\\['major'\\]\\|\\[:operatingsystemmajrelease\\]\\|\\[:os\\]\\[:release\\]\\[:major\\]\\)\\(\\.to_\\(i\\|\\s\\)\\)\\? \\(\\(<=\\|==\\) '\\?6'\\?\\|< '\\?7'\\?\\)\\|\\['\\?6'\\?, ?'\\?7'\\?\\]\\|\\(oel\\|rhel\\|centos\\|el\\).6\\|versioncmp($facts\\['os'\\]\\['release'\\]\\['major'\\], '6')" '#{dir}' --exclude-dir=.{plan.gems,gems,git} --exclude=\\* --include=\\*.{rb,pp}@

unless grep_results.empty?
  fail "ERROR: EL6 detritus detected under #{dir}:\n\n #{grep_results}\n\n"
end


warn "\n\nFINIS: #{__FILE__}"


