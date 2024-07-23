#!/usr/bin/env ruby

require 'json'
require 'fileutils'

stdin = STDIN.read
params = JSON.parse(stdin)

Dir.chdir(params['path'])

Dir.glob('data/**/OracleLinux*.yaml') do |oracle_data|
  next if %r{-[0-7]\.yaml$}.match?(oracle_data)
  rocky_data = oracle_data.sub('OracleLinux', 'Rocky')
  next if File.exist?(rocky_data)
  FileUtils.cp(oracle_data, rocky_data)
end

Dir.glob('data/**/Rocky*.yaml') do |rocky_data|
  alma_data = rocky_data.sub('Rocky', 'AlmaLinux')
  next if File.exist?(alma_data)
  FileUtils.cp(rocky_data, alma_data)
end

# Add EL9 data anywhere we have EL8 data
el = ['Rocky', 'AlmaLinux', 'CentOS', 'RedHat', 'OracleLinux']
el.each do |supported_os|
  Dir.glob("data/**/#{supported_os}-8.yaml") do |el8_data|
    el9_data = el8_data.sub('8', '9')
    next if File.exist?(el9_data)
    FileUtils.cp(el8_data, el9_data)
  end
end
