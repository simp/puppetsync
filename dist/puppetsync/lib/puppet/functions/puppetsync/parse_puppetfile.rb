# Parse Puppetfile contents
Puppet::Functions.create_function(:'puppetsync::parse_puppetfile') do
  dispatch :parse_puppetfile do
    param 'String', :content
    param 'String', :default_moduledir
    return_type 'Hash'
  end

  def parse_puppetfile(content, default_moduledir)
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    Puppet::Util::Log.log_func(closure_scope, :warning, ["=======","======="])
    pdsl = PuppetfileDSLReader.new(content, default_moduledir)

    # Stringify all keys (because Puppet can't handle symbols)
    Hash[pdsl.modules.map{|k,v| [k, Hash[v.map{|x,y| [x.to_s,y]} ]] }]
  end

  class PuppetfileDSL
    # A barebones implementation of the Puppetfile DSL
    #
    # @api private
    @lines = []
    def initialize(librarian)
    Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : librarian='#{librarian}'" )
      @librarian = librarian
    end

    def mod(name, args = nil)
    Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : name='#{name}'" )
      @librarian.add_module(name, args)
    end

    def forge(location)
    Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : location='#{location}'" )
      @librarian.set_forge(location)
    end

    def moduledir(location)
    Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : location='#{location}'" )
      @librarian.set_moduledir(location)
    end

    def method_missing(method, *args)
      raise NoMethodError, _("unrecognized declaration '%{method}'") % {method: method}
    end
  end


  class PuppetfileDSLReader

    attr_reader :modules
    attr_reader :module_dirs

    def initialize(puppetfile_data, default_moduledir)
      @module_dir = nil
      @module_dirs = []
      @modules = {}

      dsl = PuppetfileDSL.new(self)

      if default_moduledir
        puppetfile_data = "moduledir '#{default_moduledir}'  # <-- default_moduledir, added by PuppetfileDSLReader\n\n#{puppetfile_data}"
        Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : puppetfile_data:\n\n#{puppetfile_data}" )
        Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : BEFORE dsl.instance_eval(puppetfile_data)" )
        dsl.instance_eval(puppetfile_data)
        Puppet.warning("======= #{self.class.to_s} #{__method__.to_s} : AFTER dsl.instance_eval(puppetfile_data)" )
      end
    end

    def self.from_puppetfile(path)
      self.new(File.read(path))
    end

    def add_module(name, args)
      rel_path = File.join(@module_dir,name)

      if args.is_a?(Hash) && install_path = args.fetch(:install_path,false)
        install_path = install_path
      else
        install_path = @module_dir
      end

      # emulate r10k's namespace-chopping tendencies
      mod_rel_path = File.join(File.dirname(rel_path),  rel_path.split(%r{[-/]}).last)


      info = args.merge({
        :name         => name,
        :rel_path     => rel_path,
        :repo_name    => File.basename(args[:git], '.git'),
        :mod_rel_path => mod_rel_path,
        # repos basename, also the second half of the `org-mod_name` convention
        :mod_name     => File.basename(mod_rel_path),
        :install_path => install_path,
      })
      @modules[rel_path]=info
    end

    def set_forge(location)
    end

    def set_moduledir(location)
      @module_dirs << location
      @module_dir = location
    end

    def each
      @modules.each
    end
  end
end
