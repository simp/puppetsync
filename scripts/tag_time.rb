require 'yaml'

log_ref=`git log -1 --format=%H`.strip
tag_refs=`git show-ref --tags | grep #{log_ref}`.strip.split("\n").map{|x| y=x.split(/\s+/) ; [y.last.gsub(%r[refs/tags/],''), y.first]   }
tag_refs = Hash[tag_refs]

path=File.join(File.basename(File.dirname(Dir.pwd)), File.basename(Dir.pwd))

puts "== #{path} #{log_ref} #{tag_refs.keys.join(',')}"

# ------------------------------------------------------
ENV['FACTER_facts_dir'] || fail( 'no ENV[\'FACTER_facts_dir\']')

# ------------------------------------------------------
report_file = File.join(ENV['FACTER_facts_dir'],'repo_tags_report.yaml')

unless File.exists? report_file
  data = {}
else
  data = YAML.load_file report_file
end



# ------------------------------------------------------
data[path] = {:tags => tag_refs.keys, :ref => log_ref }

# ------------------------------------------------------
suggested_tag = nil
_d = data[path]
if File.exists? 'metadata.json'
  require 'facter'
  metadata = Facter.value :module_metadata
  version = metadata['version']
  data[path][:version] = version

  _d[:tags].each do |tag|

    if _d.key?(:version) && (
        tag==_d[:version] ||
        tag=="simp-#{version}" ||
        tag=="simp6.0.0-#{version}" ||
        tag="v#{version}" ||
        tag =~ /simp-#{version}-.*/
    )
      _d[:result] = :DONE
    end
  end
else
  exit 0
end

close_tags = nil
if _d.key? :version
  close_tags = `git show-ref --tags`.strip.split("\n").select{ |x| x=~ /#{_d[:version]}/ }.map{|x| x.sub(%r{^.*tags/},'')}
end

_d[:forge_org] = metadata['forge_org']
if metadata['forge_org'] == 'simp'
   suggested_tag = version
else
   suggested_tag = "simp6.0.0-#{version}"
end

if close_tags.include? suggested_tag
  suggested_tag = suggested_tag + "-post1"
end

# ------------------------------------------------------
unless _d.key? :result
  if _d.key?(:version)
    _d[:result] = :CREATE
    _d[:suggested_tag]=suggested_tag  if suggested_tag
    _d[:close_tags]=close_tags  if close_tags
  else
    _d[:result] = :FIXME_NO_VERSION
  end
end

if _d[:result] == :CREATE

  remote = `git remote -v`.strip.split("\n").select{|x| x=~ /origin.*push/ }.first.split(/[\t ]/)[1]
  remote_org = File.basename(File.dirname(remote))
  remote_name = File.basename remote
  danger_remote = "git@github.com:#{remote_org}/#{remote_name}"

  cmds = ["git tag #{suggested_tag}",
          "git remote add upstreamDANGER #{danger_remote}",
          "git push upstreamDANGER #{suggested_tag}"
  ]
  cmd = cmds.join(" && ") 
  require 'pry'; binding.pry unless suggested_tag =~ /^simp6\.0\.0-/
  puts %x{#{cmd}}
  _d[:resolution] = :TAG_CREATED

end
require 'pry'; binding.pry if ( _d.key?(:tags) && _d[:tags].size > 0 && _d.key?(:version) && _d[:result] != :DONE && data.size > 80  )
File.open( report_file, 'w' ){|f| f.puts data.to_yaml }
