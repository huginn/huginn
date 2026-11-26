require 'rails_helper'
require 'tmpdir'
require 'fileutils'

describe GemfileHelper do
  context 'parse_each_agent_gem' do
    VALID_STRINGS = [
      ['huginn_nlp_agents(~> 0.2.1)', [
        ['huginn_nlp_agents', '~> 0.2.1']
      ]],
      ['huginn_nlp_agents(~> 0.2.1, git: http://github.com/dsander/huginn.git, branch: agents_in_gems)',
        [['huginn_nlp_agents', '~> 0.2.1', git: 'http://github.com/dsander/huginn.git', branch: 'agents_in_gems']]
      ],
      ['huginn_nlp_agents(~> 0.2.1, git: http://github.com/dsander/huginn.git, ref: 2342asdab)  , huginn_nlp_agents(~> 0.2.1)', [
        ['huginn_nlp_agents', '~> 0.2.1', git: 'http://github.com/dsander/huginn.git', ref: '2342asdab'],
        ['huginn_nlp_agents', '~> 0.2.1']
      ]],
      ['huginn_nlp_agents(~> 0.2.1, path: /tmp/test)', [
        ['huginn_nlp_agents', '~> 0.2.1', path: '/tmp/test']
      ]],
      ['huginn_nlp_agents', [
        ['huginn_nlp_agents']
      ]],
      ['huginn_nlp_agents, test(0.1), test2(github: test2/huginn_test)', [
        ['huginn_nlp_agents'],
        ['test', '0.1'],
        ['test2', github: 'test2/huginn_test']
      ]],
      ['huginn_nlp_agents(git: http://github.com/dsander/huginn.git, ref: 2342asdab)', [
        ['huginn_nlp_agents', git: 'http://github.com/dsander/huginn.git', ref: '2342asdab']
      ]],
    ]

    it 'parses valid gem strings correctly' do
      VALID_STRINGS.each do |string, outcomes|
        GemfileHelper.parse_each_agent_gem(string) do |args|
          expect(args).to eq(outcomes.shift)
        end
      end
    end

    it 'does nothing when nil is passed' do
      expect { |b| GemfileHelper.parse_each_agent_gem(nil, &b) }.not_to yield_control
    end

    it 'does nothing when an empty string is passed' do
      expect { |b| GemfileHelper.parse_each_agent_gem('', &b) }.not_to yield_control
    end
  end

  describe '.additional_gem_locale_paths' do
    around do |example|
      Dir.mktmpdir('huginn-translations-') do |root|
        @locale_root = root
        @yml_path = File.join(root, 'config/locales/xx.yml')
        @ruby_path = File.join(root, 'config/locales/navigation/xx.rb')
        FileUtils.mkdir_p(File.dirname(@ruby_path))
        File.write(@yml_path, "xx: {}\n")
        File.write(@ruby_path, '{ xx: {} }')
        File.write(File.join(root, 'config/locales/README.md'), 'Translation notes')
        FileUtils.mkdir_p(File.join(root, 'other'))
        File.write(File.join(root, 'other/xx.yml'), "xx: {}\n")
        example.run
      end
    end

    before do
      loaded_specs = Gem.loaded_specs.merge(
        'huginn_test_locale' => double(full_gem_path: @locale_root)
      )
      allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
    end

    it 'does not load locale files when no additional gems are configured' do
      expect(described_class.additional_gem_locale_paths(nil)).to eq([])
      expect(described_class.additional_gem_locale_paths('')).to eq([])
    end

    it 'loads Ruby and YAML files including nested locale directories' do
      expect(described_class.additional_gem_locale_paths('huginn_test_locale'))
        .to match_array([@yml_path, @ruby_path])
    end

    it 'uses the activated gem with version and source options' do
      expect(described_class.additional_gem_locale_paths('huginn_test_locale(~> 1.0, path: /unused)'))
        .to match_array([@yml_path, @ruby_path])
    end

    it 'does not add files from unrelated or unavailable gems' do
      expect(described_class.additional_gem_locale_paths('not_installed')).to eq([])
      expect(described_class.additional_gem_locale_paths('rails')).not_to include(@yml_path, @ruby_path)
    end

    it 'adds each locale file only once when a gem is repeated' do
      expect(described_class.additional_gem_locale_paths('huginn_test_locale, huginn_test_locale'))
        .to match_array([@yml_path, @ruby_path])
    end
  end
end
