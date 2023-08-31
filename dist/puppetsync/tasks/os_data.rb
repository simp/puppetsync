#!/usr/bin/env ruby

require 'json'
require 'fileutils'

stdin = STDIN.read
params = JSON.parse(stdin)

Dir.chdir(params['path'])

Dir.glob('data/**/os/OracleLinux*.yaml').each do |oracle_data|
  rocky_data = oracle_data.sub('OracleLinux', 'Rocky')
  next if File.exist?(rocky_data)
  FileUtils.cp(oracle_data, rocky_data)
end

Dir.glob('data/**/os/Rocky*.yaml').each do |rocky_data|
  alma_data = rocky_data.sub('Rocky', 'AlmaLinux')
  next if File.exist?(alma_data)
  FileUtils.cp(rocky_data, alma_data)
end

