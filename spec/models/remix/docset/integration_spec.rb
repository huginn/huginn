require 'rails_helper'

describe 'Docset Integration' do
  describe 'ToolRegistry' do
    it 'includes all docset tools' do
      tool_names = Remix::ToolRegistry::TOOLS.map(&:tool_name)

      expect(tool_names).to include('list_docsets')
      expect(tool_names).to include('install_docset')
      expect(tool_names).to include('search_docs')
      expect(tool_names).to include('uninstall_docset')
    end

    it 'can find each docset tool by name' do
      %w[list_docsets install_docset search_docs uninstall_docset].each do |name|
        tool_class = Remix::ToolRegistry.find_tool(name)
        expect(tool_class).not_to be_nil, "Expected to find tool '#{name}' in registry"
        expect(tool_class.tool_name).to eq(name)
      end
    end

    it 'generates valid OpenAI tool definitions for docset tools' do
      all_tools = Remix::ToolRegistry.all_tools
      docset_tools = all_tools.select { |t| t[:function][:name].start_with?('list_doc', 'install_doc', 'search_doc', 'uninstall_doc') }

      expect(docset_tools.length).to eq(4)

      docset_tools.each do |tool|
        expect(tool[:type]).to eq('function')
        expect(tool[:function][:name]).to be_present
        expect(tool[:function][:description]).to be_present
        expect(tool[:function][:parameters]).to be_a(Hash)
      end
    end
  end

  describe 'Orchestrator skills' do
    let(:user) { users(:bob) }
    let(:remix) do
      RemixConversation.create!(user: user, title: 'Test')
    end

    it 'includes DocumentationSkill in the skill list' do
      orchestrator = Remix::Orchestrator.new(remix)
      # Access the private method via send
      all_skills = orchestrator.send(:all_skill_classes)

      expect(all_skills).to include(Remix::Skills::DocumentationSkill)
    end

    it 'activates DocumentationSkill for documentation-related messages' do
      remix.messages.create!(role: 'user', content: 'Show me the docs for Array.push')

      orchestrator = Remix::Orchestrator.new(remix)
      context = orchestrator.send(:active_skills_context)

      expect(context).to include('Documentation Search')
      expect(context).to include('search_docs')
    end

    it 'does not activate DocumentationSkill for unrelated messages' do
      remix.messages.create!(role: 'user', content: 'Create a new WebsiteAgent')

      orchestrator = Remix::Orchestrator.new(remix)
      context = orchestrator.send(:active_skills_context)

      expect(context).not_to include('Documentation Search')
    end
  end
end
