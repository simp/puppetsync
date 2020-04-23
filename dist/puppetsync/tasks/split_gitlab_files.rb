#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'

def split_gitlab_file(file, include_dirname='.repo_metadata')
  include_filename = '.gitlab-ci-acceptance.repo.yml'
  project_root = File.dirname(file)
  FileUtils.mkdir_p(File.join(project_root, include_dirname))
  include_file = File.join(project_root, include_dirname , include_filename)
  warn "=== file: #{file}"

  content = File.read(file)
  rx = %r{^# Acceptance tests\n# ==============================================================================$|^# Acceptance Tests\n#---+$}
  original, acceptance = content.split(rx)
  unless acceptance
    if File.exists? include_file
      puts "  -- #{include_file} already exists!"
      return
    elsif file =~ %r[#{File.join('simp_options','.gitlab-ci.yml')}$]
      acceptance = "# No acceptance tests for this module"
    else
      fail "ERROR: No acceptance tests split for #{file}"
    end
  end
  ##extra = <<~EXTRA
  ##include:
  ##  - local: '/.gitlab-ci/#{include_file}'
  ##EXTRA

  acceptance = [
    '# The content of this section can be customized by creating and populating',
    '# the file:',
    '#',
    '#   .repo_metadata/.gitlab-ci-acceptance.repo.yml',
    '#',
    '# -----------------------------------------------------------------------------',
    '',
  ].join("\n") + acceptance
  acceptance.gsub!(/pup_5_5_16|pup_5_5_10/, 'pup_5_5_17')
  acceptance.gsub!(/pup5\.5\.16|pup5\.5\.10/, 'pup5.5.17')
  File.open(include_file, 'w'){|f| f.puts acceptance }
 ## File.open(file, 'w'){|f| f.puts "#{original}\n#{extra}" }
 ## File.open(file, 'w'){|f| f.puts "#{original}" }


end

require 'json'
stdin = STDIN.read
params = JSON.parse(stdin)
warn stdin

files = params['repo_paths'].map{|x| File.join(x,'.gitlab-ci.yml') } || ARGV
fail("No repo_paths given") unless params['repo_paths'] && ARGV.empty?

files.each do |x|
  split_gitlab_file x
end
warn "FINIS: #{__FILE__}"
