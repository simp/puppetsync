require 'yaml'

# Yanked from simp/rubygem-simp-rake-helpers
#
# This works around
class Puppetsync::R10KHelper
  attr_accessor :puppetfile
  attr_accessor :modules
  attr_accessor :basedir

  require 'r10k/puppetfile'

  # Horrible, but we need to be able to manipulate the cache
  class R10K::Git::ShellGit::ThinRepository
    def cache_repo
      @cache_repo
    end

    # Return true if the repository has local modifications, false otherwise.
    def dirty?
      repo_status = false

      return repo_status unless File.directory?(path)

      Dir.chdir(path) do
        %x(git update-index -q --ignore-submodules --refresh)
        repo_status = "Could not update git index for '#{path}'" unless $?.success?

        unless repo_status
          %x(git diff-files --quiet --ignore-submodules --)
          repo_status = "'#{path}' has unstaged changes" unless $?.success?
        end

        unless repo_status
          %x(git diff-index --cached --quiet HEAD --ignore-submodules --)
          repo_status = "'#{path}' has uncommitted changes" unless $?.success?
        end

        unless repo_status
          untracked_files = %x(git ls-files -o -d --exclude-standard)

          if $?.success?
            unless untracked_files.empty?
              untracked_files.strip!

              if untracked_files.lines.count > 0
                repo_status = "'#{path}' has untracked files"
              end
            end
          else
            # We should never get here
            raise Error, "Failure running 'git ls-files -o -d --exclude-standard' at '#{path}'"
          end
        end
      end

      repo_status
    end
  end

  def initialize(puppetfile)
    @modules = []
    @basedir = File.dirname(File.expand_path(puppetfile))

    Dir.chdir(@basedir) do

      R10K::Git::Cache.settings[:cache_root] = File.join(@basedir,'.r10k_cache')

      unless File.directory?(R10K::Git::Cache.settings[:cache_root])
        FileUtils.mkdir_p(R10K::Git::Cache.settings[:cache_root])
      end

      r10k = R10K::Puppetfile.new(Dir.pwd, nil, puppetfile)
      r10k.load!

      @modules = r10k.modules.collect do |mod|
        mod_status = mod.repo.repo.dirty?

        mod = {
          :name        => mod.name,
          :path        => mod.path.to_s,
          :git_source  => mod.repo.repo.origin,
          :git_ref     => mod.repo.head,
          :module_dir  => mod.basedir,
          :status      => mod_status ? mod_status : :known,
          :r10k_module => mod,
          :r10k_cache  => mod.repo.repo.cache_repo
        }
      end
    end

    module_dirs = @modules.collect do |mod|
      mod = mod[:module_dir]
    end

    module_dirs.uniq!

    module_dirs.each do |module_dir|
      known_modules = @modules.select do |mod|
        mod[:module_dir] == module_dir
      end

      known_modules.map! do |mod|
        mod = mod[:name]
      end

      current_modules = Dir.glob(File.join(module_dir,'*')).map do |mod|
        mod = File.basename(mod)
      end

      (current_modules - known_modules).each do |mod|
        # Did we find random git repos in our module spaces?
        if File.exist?(File.join(module_dir, mod, '.git'))
          @modules << {
            :name        => mod,
            :path        => File.join(module_dir, mod),
            :module_dir  => module_dir,
            :status      => :unknown,
          }
        end
      end
    end
  end

  def puppetfile
    last_module_dir = nil
    pupfile = Array.new

    @modules.each do |mod|
      module_dir = mod[:path].split(@basedir.to_s).last.split('/')[1..-2].join('/')

      next unless mod[:r10k_module]

      if last_module_dir != module_dir
        pupfile << "moduledir '#{module_dir}'\n"
        last_module_dir = module_dir
      end

      pupfile << "mod '#{mod[:r10k_module].title}',"
      pupfile << "  :git => '#{mod[:git_source]}',"
      pupfile << "  :ref => '#{mod[:r10k_module].repo.head}'\n"
    end

    pupfile << '# vim: ai ts=2 sts=2 et sw=2 ft=ruby'

    pupfile.join("\n")
  end

  def each_module(&block)
    Dir.chdir(@basedir) do
      @modules.each do |mod|
        # This works for Puppet Modules

        block.call(mod)
      end
    end
  end

  def unknown_modules
    @modules.select do |mod|
      mod[:status] == :unknown
    end.map do |mod|
      mod = mod[:name]
    end
  end
end

