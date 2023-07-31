#!/opt/puppetlabs/bolt/bin/ruby

require 'fileutils'
require 'json'

require 'tempfile'
require 'tmpdir'

BUNDLER_EXE=ENV['BUNDLER_EXE'] || "/opt/puppetlabs/bolt/bin/bundle"
RAKE_EXE=ENV['RAKE_EXE'] || "/opt/puppetlabs/bolt/bin/rake"
BUNDLE_PATH=ENV['BUNDLE_PATH']||'../../.vendor/bundle'

def tmp_bundle_rake_execs(repo_path, tasks, save_rake_stdout: false)
  Dir.mktmpdir('tmp_bundle_rake_execs') do |tmp_dir|
    Dir.chdir repo_path
    gemfile_lock = false
    if File.exist?('Gemfile.lock')
      gemfile_lock = File.expand_path('Gemfile.lock',tmp_dir)
      FileUtils.cp File.join(repo_path, 'Gemfile.lock'), gemfile_lock
    end
    results = []
    rake_stdout_files={}
    require 'bundler'
    require 'rake'
    Bundler.with_unbundled_env do
      #sh "#{BUNDLER_EXE} config path .vendor/bundle &> /dev/null"
      sh "#{BUNDLER_EXE} install --path '#{BUNDLE_PATH}'  &> /dev/null"
      tasks.each do |task|
        puts
        cmd = "#{BUNDLER_EXE} exec #{RAKE_EXE} #{task}  "
        if save_rake_stdout
          out_file = "_rake__stdout.#{task}"
          cmd += " > #{out_file}"
          rake_stdout_files[task] = out_file
        end
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
    return rake_stdout_files if save_rake_stdout
  end
end


# ARGF hack to allow use run the task directly as a ruby script while testing
metadata_json_path = false
overwrite_existing_tags = false
upstream_remote = 'origin'
if ARGF.filename == '-'
  stdin = ''
  warn "ARGF.file.lineno: '#{ARGF.file.lineno}'"
  stdin = ARGF.file.read
  warn "== stdin: '#{stdin}'"
  params = JSON.parse(stdin)
  metadata_json_path = params['filename']
  overwrite_existing_tags = params['overwrite_existing_tags']
  upstream_remote = params['upstream_remote']
else
  metadata_json_path = ARGF.filename
end


# Read content from metadata.json metadata_json_path
warn "metadata_json_path: '#{metadata_json_path}'"
raise('No metadata.json path given') unless metadata_json_path
pupmod_metadata = JSON.parse File.read(metadata_json_path)
repo_path = File.dirname metadata_json_path



unless ENV['UPDATE_NON_SIMP_MODULES'] == 'yes'
  if pupmod_metadata['name'] !~ %r{\Asimp[-/]}
    warn("\n\n\n== WARNING: SKIPPING update of non-simp module (#{content['name']}) (force with `UPDATE_NON_SIMP_MODULES=yes`)\n\n\n")
  else
    task_output_files = tmp_bundle_rake_execs(repo_path, ['pkg:create_tag_changelog'], save_rake_stdout: true)

    annotated_tag_file = task_output_files['pkg:create_tag_changelog']
    fail "ERROR: no file at #{annotated_tag_file}" unless File.exist?(annotated_tag_file)

    # strip extra newlines
    annotated_tag = File.read(task_output_files['pkg:create_tag_changelog']).strip

    annotated_tag_file = '_annotated_tag.txt'
    # get rid of RPM date + email + version changelog line(s)
    annotated_tag = annotated_tag.lines.reject{ |x| x =~ %r{^\* (\w{3}) (\w{3}) (\d{2}) (\d{4}) .*@} }.join

    File.open(annotated_tag_file,'w'){|f| f.puts annotated_tag }

    if task_output_files
      task_output_files.values.each{|f| FileUtils.rm_f(f) }
    end

    sh ">&2 git tag -D '#{pupmod_metadata['version']}'" if overwrite_existing_tags
    sh ">&2 git tag -a '#{pupmod_metadata['version']}' -F '#{annotated_tag_file}'"
    sh ">&2 git push '#{upstream_remote}'  '#{pupmod_metadata['version']}'"
    exit 0

  end
end
