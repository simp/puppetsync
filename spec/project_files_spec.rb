require 'spec_helper'

# Cheap, broad sanity checks over the files the plans depend on at runtime.
describe 'project file sanity' do
  describe 'task implementations' do
    Dir.glob(File.join(TASKS_DIR, '*.rb')).sort.each do |script|
      it "#{File.basename(script)} passes ruby -c" do
        _stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-c', script)
        expect(status).to be_success, stderr
      end
    end
  end

  describe 'task metadata' do
    Dir.glob(File.join(TASKS_DIR, '*.json')).sort.each do |metadata|
      it "#{File.basename(metadata)} is valid JSON" do
        expect { JSON.parse(File.read(metadata)) }.not_to raise_error
      end
    end
  end

  describe 'Hiera data and project config' do
    yaml_files = Dir.glob(File.join(REPO_ROOT, 'data', '**', '*.yaml')) +
                 %w[bolt-project.yaml hiera.yaml inventory.yaml].map { |f| File.join(REPO_ROOT, f) }

    yaml_files.sort.each do |path|
      it "#{path.delete_prefix("#{REPO_ROOT}/")} parses as YAML" do
        expect { YAML.load_file(path, aliases: true) }.not_to raise_error
      end
    end
  end

  describe 'latest symlinks' do
    %w[data/sync/configs/latest.yaml data/sync/repolists/latest.yaml].each do |link|
      it "#{link} resolves to an existing file" do
        expect(File).to exist(File.join(REPO_ROOT, link))
      end
    end
  end
end
