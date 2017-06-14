require 'rails_helper'

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
end
