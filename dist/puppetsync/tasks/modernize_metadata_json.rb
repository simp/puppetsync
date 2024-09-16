#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'

require 'tempfile'
require 'tmpdir'

require 'fileutils'

def bump_version(file)
  # Read content from metadata.json file
  warn "file: '#{file}'"
  raise('No metadata.json path given') unless file
  dir = File.dirname(file)
  content = File.read(file)
  data = JSON.parse(content)

  # bump y version
  parts = data['version'].split(/[\.-]/)
  parts[1] = (parts[1].to_i + 1).to_s
  parts[2] = '0'
  new_version = parts.join('.')
  data['version'] = new_version

  File.open(file,'w'){|f| f.puts(JSON.pretty_generate(data)) }
  warn "\n\n++ processed '#{file}'"

  if new_version
    if file =~ /\.erb$/
      warn "SKIP VERSION BUMP: File is not .erb: #{file}"
      return
    end

    changelog_file = File.join(dir,'CHANGELOG')
    unless File.exist? changelog_file
      warn "SKIP VERSION BUMP: No CHANGELOG"
      return
    end

    changelog = File.read(changelog_file)
    require 'date'
    new_lines = []
    new_lines << DateTime.now.strftime("* %a %b %d %Y Steven Pritchard <steve@sicura.us> - #{new_version}")
    new_lines << '- [puppetsync] Update module dependencies to support simp-iptables 7.x'
    changelog = new_lines.join("\n") + "\n\n" + changelog
    File.open(changelog_file,'w'){|f| f.puts changelog; f.flush }
  end
end

def tmp_bundle_rake_execs(repo_path, tasks)
  Dir.mktmpdir('tmp_bundle_rake_execs') do |tmp_dir|
    Dir.chdir repo_path
    gemfile_lock = false
    if File.exist?('Gemfile.lock')
      gemfile_lock = File.expand_path('Gemfile.lock',tmp_dir)
      FileUtils.cp File.join(repo_path, 'Gemfile.lock'), gemfile_lock
    end
    results = []
    require 'bundler'
    require 'rake'
    Bundler.with_unbundled_env do
      #sh "/opt/puppetlabs/bolt/bin/bundle config path .vendor/bundle &> /dev/null"
      sh "/opt/puppetlabs/bolt/bin/bundle install --path ../../.vendor/bundle  &> /dev/null"
      tasks.each do |task|
        puts
        cmd = "/opt/puppetlabs/bolt/bin/bundle exec /opt/puppetlabs/bolt/bin/rake #{task}"
        results << sh(cmd)
      end
      if gemfile_lock
        FileUtils.cp gemfile_lock, File.join(repo_path, 'Gemfile.lock')
      else
        FileUtils.rm('Gemfile.lock')
      end
    end
    unless results.all?{ |x| x }
      warn 'bad result'
    end
  end
end

def transform_puppet_version_requirements(content)
  #regexp_for_low_high_bounds = %r[\A(?<low_op>>=?) (?<low_ver>\d+.*) (?<high_op><=?) (?<high_ver>\d+.*)\Z]
  content['requirements'].select{|x| x['name'] == 'puppet' }.map do |x|
    #x['version_requirement'].gsub!( regexp_for_low_high_bounds ) do |y|
    #  m = Regexp.last_match
    #  "#{m[:low_op} #{m[:low_ver]} >= 6.22.1 < 8.0.0"
    #end
    x['version_requirement'] = '>= 7.0.0 < 9.0.0'
  end
end

def transform_module_dependencies(content)
  dep_sections = [
    content['dependencies'],
    (content['simp']||{})['optional_dependencies']
  ].select{|x| x }

  dep_sections.each do |dependencies|
    # puppet/systemd 4.0.2 addd Rocky Linux 8, 5.x drops puppet 6 support
    dependencies.select{|x| x['name'].sub('-', '/') == 'puppet/systemd' || x['name'].sub('-', '/') == 'camptocamp/systemd' }.each do |x|
      x['name'] = 'puppet/systemd'
      x['version_requirement'] = '>= 4.0.2 < 7.0.0'
    end
    # stdlib 8 adds Rocky 8, 8.4.0 (beware ensure_packages flip: https://github.com/puppetlabs/puppetlabs-stdlib/pull/1196)
    dependencies.select{|x| x['name'] == 'puppetlabs/stdlib' }.each do |x|
      x['version_requirement'] = '>= 8.0.0 < 10.0.0'
    end
    # augeasproviders modules moved to Vox Pupuli
    dependencies.select{|x| x['name'].split(%r{[-/]}).first == "herculesteam" }.each do |x|
      x['name'].sub!('herculesteam', 'puppet')
    end
    # nsswitch modules moved to puppet from trlinkin
    dependencies.select{|x| x['name'].sub('-', '/') == 'trlinkin/nsswitch' }.each do |x|
      x['name'].sub!('trlinkin', 'puppet')
    end

    # Update dependency versions
    dependencies.select{|x| x.key?('name') && x.key?('version_requirement') }.each do |x|
      version_requirements = JSON.parse(File.read(File.join(__dir__, "..", "dist", "puppetsync", "data", "version_requirements.json")))

      name = x['name'].sub('-', '/')
      next unless version_requirements.key?(name)

      x['version_requirement'] = version_requirements[name]
    end
  end
end

def transform_operatingsystem_support(content)
  unless content.keys.include? 'operatingsystem_support'
    warn "SKIPPING: NO operatingsystem_support key exists in metadata.json for #{content['name']}"
    return
  end

  case content['name'].delete_prefix('simp-')
  # Not supported on EL8
  when 'tpm', 'upstart', 'chkrootkit', 'sudosh'
    return
  # Not tested on EL8 (yet)
  when 'hirs_provisioner', 'simp_ipa', 'simp_pki_service'
    return
  # No specific OS support listed
  when 'simp_banners', 'simplib'
    return
  end

  el = ['Rocky', 'AlmaLinux', 'CentOS', 'RedHat', 'OracleLinux']

  # We only want to manipulate the supported OS list if it includes RHEL 8.
  return unless content['operatingsystem_support'].any?{|x| x['operatingsystem'] == 'RedHat' && x['operatingsystemrelease']&.include?('8') }

  el.each do |supported_os|
    ['8', '9'].each do |supported_version|
      items = content['operatingsystem_support'].select{|x| x['operatingsystem'] == supported_os }
      content['operatingsystem_support'] << { 'operatingsystem' => supported_os } if items.empty?

      content['operatingsystem_support'].select{|x| x['operatingsystem'] == supported_os }.map do |x|
        x['operatingsystemrelease'] ||= []
        unless x['operatingsystemrelease'].include? supported_version
          x['operatingsystemrelease'] << supported_version
        end
      end
    end
  end
end

# ARGF hack to allow use run the task directly as a ruby script while testing
if ARGF.filename == '-'
  stdin = ''
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  file = params['filename']
else
  file = ARGF.filename
end

# Read content from metadata.json file
warn "file: '#{file}'"
raise('No metadata.json path given') unless file
content = JSON.parse File.read(file)

unless ENV['UPDATE_NON_SIMP_MODULES'] == 'yes'
  if content['name'] !~ %r{\Asimp[-/]}
    warn("\n\n\n== WARNING: SKIPPING update of non-simp module (#{content['name']}) (force with `UPDATE_NON_SIMP_MODULES=yes`)\n\n\n")
    exit 0
  end
end

# Transform content
warn "\n== Modernizing metadata.json content"
original_content_str = content.to_s

# These methods mutate `content` and its contents by reference
# ------------------------------------------------------------------------------
transform_puppet_version_requirements(content)
# transform_operatingsystem_support(content)
transform_module_dependencies(content)

# Write content back to original file
File.open(file, 'w') { |f| f.puts JSON.pretty_generate(content) }

if content.to_s == original_content_str
  warn '  == content unchanged'
else
  warn '  ++ content was changed!'
  bump_version(file) # Not needed so soon
  unless ENV['SKIP_RAKE_TASKS'] == 'yes'
    repo_path = File.dirname file
    tmp_bundle_rake_execs(repo_path, ['metadata_lint', 'pkg:check_version', 'pkg:compare_latest_tag'])
  end
end

# Sanity check: Validate that the file is still valid JSON
# NOTE: Handle heavier, gitlab/domain-aware lint checks in other tasks
warn "\n== Running a test json load #{file} to validate its syntax (current dir: #{Dir.pwd}"
require 'json'
sleep(2)
JSON.parse File.read(file)
warn "  ++ Test load (JSON syntax)  on #{file} succeeded!"

warn "\n\nFINIS: #{__FILE__}"
