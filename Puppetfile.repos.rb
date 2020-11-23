#!/opt/puppetlabs/bolt/bin/ruby

require 'json'
require 'net/http'

response = Net::HTTP.get_response(URI.parse('https://puppetlabs.github.io/iac/modules.json')).body
modules_list = JSON.parse(response)
modules_list.each do |name, data|
  puts "mod '#{data['slug']}', git: 'https://github.com/#{data['github']}', branch: 'main'"
end
