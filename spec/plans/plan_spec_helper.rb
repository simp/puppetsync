# Helper for BoltSpec plan specs (simp/puppetsync#76).
#
# These specs run the project's plans with stubbed tasks/commands — no
# clones, no network. They require Bolt's Ruby (bolt_spec ships with the
# openbolt package) and are excluded from the default plain-Ruby `rspec`
# run via `.rspec`. Run them with:
#
#   GEM_HOME=.gems /opt/puppetlabs/bolt/bin/gem install rspec --no-document
#   GEM_HOME=.gems /opt/puppetlabs/bolt/bin/ruby .gems/bin/rspec -O /dev/null spec/plans
#
# Conventions learned the hard way:
#   - Stub matching is last-defined-wins: declare catch-all
#     `allow_out_message` BEFORE specific `expect_out_message` stubs
#   - Plans that default parameters from `lookup()` must be given those
#     parameters explicitly, or the spec depends on the project's Hiera data
require 'bolt_spec/plans'

PROJECT_ROOT = File.expand_path(File.join(__dir__, '..', '..')) unless defined?(PROJECT_ROOT)

RSpec.shared_context 'puppetsync plan specs' do
  include BoltSpec::Plans

  def modulepath
    [
      File.join(PROJECT_ROOT, 'spec', 'fixtures', 'modules'),
      File.join(PROJECT_ROOT, 'dist'),
      File.join(PROJECT_ROOT, 'modules'),
      File.join(PROJECT_ROOT, '.modules'),
    ]
  end

  before(:each) do
    BoltSpec::Plans.init
    # Sensitive[String[1]] / String[1] params default from these
    ENV['GITHUB_API_TOKEN'] ||= 'spec-dummy-token'
    ENV['JIRA_USER'] ||= 'spec-dummy-user'
    ENV['JIRA_API_TOKEN'] ||= 'spec-dummy-token'
  end
end
