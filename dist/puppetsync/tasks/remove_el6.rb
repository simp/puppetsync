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




require 'pry'; binding.pry


puts 'FINIS'
