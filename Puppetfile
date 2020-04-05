moduledir 'modules'

mod 'stdlib',
  :git => 'https://github.com/puppetlabs/puppetlabs-stdlib.git',
  :tag => 'v6.2.0'

##mod 'simplib',
##  :git => 'git@github.com:simp/pupmod-simp-simplib.git',
##  :tag => '4.2.0'

mod 'puppetlabs/ruby_task_helper',
  :git => 'https://github.com/puppetlabs/puppetlabs-ruby_task_helper.git',
  :tag => '0.5.1'

moduledir '_repos'
repos_puppetfile = 'Puppetfile.repos'
if File.readable?(repos_puppetfile)
  content = File.read(repos_puppetfile)
  instance_eval(content)
end

# vim: set ft=ruby :
