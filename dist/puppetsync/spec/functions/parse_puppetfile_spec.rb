require 'spec_helper'

describe 'puppetsync::parse_puppetfile' do
  let(:pf) do
    <<-PF
      moduledir 'modules'

      mod 'stdlib',
        :git => 'https://github.com/puppetlabs/puppetlabs-stdlib.git',
        :tag => 'v6.2.0'

      mod 'simplib',
        :git => 'git@github.com:simp/pupmod-simp-simplib.git',
        :tag => '4.2.0'
      moduledir '_repos'

      mod 'simp-acpid',
        :git => 'https://github.com/simp/pupmod-simp-acpid'
    PF
  end

  let(:pf_modules_hash) do
    {"modules/stdlib"=>{"git"=>"https://github.com/puppetlabs/puppetlabs-stdlib.git", "tag"=>"v6.2.0", "name"=>"stdlib", "rel_path"=>"modules/stdlib", "mod_rel_path"=>"modules/stdlib", "mod_name"=>"stdlib", "install_path"=>"modules", "repo_name"=>"puppetlabs-stdlib"}, "modules/simplib"=>{"git"=>"git@github.com:simp/pupmod-simp-simplib.git", "tag"=>"4.2.0", "name"=>"simplib", "rel_path"=>"modules/simplib", "mod_rel_path"=>"modules/simplib", "mod_name"=>"simplib", "install_path"=>"modules", "repo_name"=>"pupmod-simp-simplib"}, "_repos/simp-acpid"=>{"git"=>"https://github.com/simp/pupmod-simp-acpid", "name"=>"simp-acpid", "rel_path"=>"_repos/simp-acpid", "mod_rel_path"=>"_repos/acpid", "mod_name"=>"acpid", "install_path"=>"_repos", "repo_name"=>"pupmod-simp-acpid"}}
  end

  context 'when a simple array is passed' do
    it { is_expected.to run.with_params(pf, '.').and_return(pf_modules_hash) }
  end
end
