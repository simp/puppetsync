#!/usr/bin/env ruby

require 'json'
require 'fileutils'

stdin = STDIN.read
params = JSON.parse(stdin)

Dir.chdir(params['path'])

Dir.glob('**/.gitlab-ci.yml').each do |file|
  File.unlink(file)
end
