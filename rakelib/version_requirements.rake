# frozen_string_literal: true

namespace 'version_requirements' do
  desc 'Update version_requirements.json'
  task 'update' do |_t|
    require 'json'
    require 'httpclient'

    def forgeapi
      'https://forgeapi.puppet.com/v3'
    end

    def version_requirements_json
      File.join(
        __dir__,
        '..',
        'dist',
        'puppetsync',
        'data',
        'version_requirements.json',
      )
    end

    def version_requirements
      return @version_requirements unless @version_requirements.nil?

      @version_requirements = JSON.parse(File.read(version_requirements_json))
    end

    def module_info(module_name)
      return @cached_info[module_name] unless @cached_info.nil? || @cached_info[module_name].nil?

      @cached_info = {} if @cached_info.nil?

      response = HTTPClient.get "#{forgeapi}/modules/#{module_name}"
      info = JSON.parse response.body

      unless info['superseded_by'].nil?
        warn "  => Superseded by #{info['superseded_by']['slug']}"
        info = module_info(info['superseded_by']['slug'])
      end

      @cached_info[module_name] = info
    rescue => e
      warn e.message
      nil
    end

    def nextmajor(current_version)
      # This is a hack.  I tried to use
      # Gem::Version.new(current_version).canonical_segments,
      # but it did not work reliably.
      newver = current_version.split('.').map { |n| n.to_i }
      newver[0] += 1
      newver[1..].each_index do |n|
        newver[n + 1] = 0
      end
      newver.join('.')
    end

    req = Marshal.load(Marshal.dump(version_requirements))

    version_requirements.each do |name, version_requirement|
      warn "Checking #{name} #{version_requirement}"

      slug = name.tr('/', '-')

      info = module_info(slug)
      next if info.nil?

      module_name = info['slug']
      current_version = info['current_release']['version']

      if module_name != slug
        warn "  => Replaced with #{module_name} version #{current_version}"
        req[module_name.tr('-', '/')] = req.delete(name)
      end

      bounds = version_requirement.split(%r{\s+(?=[<>=~])}, 2)
      next if Gem::Requirement.new(bounds).satisfied_by?(Gem::Version.new(current_version))

      warn "  => #{module_name} #{current_version} out of range"
      unless bounds.length == 2
        warn '  -> Skipping update!'
        next
      end

      # Try bumping the upper bounds
      bounds[1] = "< #{nextmajor(current_version)}"
      if Gem::Requirement.new(bounds).satisfied_by?(Gem::Version.new(current_version))
        version_requirement = bounds.join(' ')
        warn "  -> Updating to #{version_requirement}"
        req[module_name.tr('-', '/')] = version_requirement
      else
        warn "  -> Unable to find a matching range! (Tried #{bounds}.)"
        next
      end
    end

    unless req == version_requirements
      File.open(version_requirements_json, 'w') do |fh|
        fh.puts JSON.pretty_generate(req)
      end
    end
  end
end
