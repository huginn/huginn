require 'rails_helper'

describe Remix::Skills::DocumentationSkill do
  let(:user) { users(:bob) }

  describe '.name' do
    it 'returns documentation' do
      expect(described_class.name).to eq('documentation')
    end
  end

  describe '.triggers' do
    it 'includes documentation-related keywords' do
      expect(described_class.triggers).to include('documentation', 'docs', 'docset')
    end
  end

  describe '.matches?' do
    it 'matches messages about documentation' do
      expect(described_class.matches?('Show me the docs for Array')).to be true
      expect(described_class.matches?('install a docset for Python')).to be true
      expect(described_class.matches?('look up the API reference')).to be true
      expect(described_class.matches?('how does HTTP.createServer work')).to be true
    end

    it 'does not match unrelated messages' do
      expect(described_class.matches?('create a new agent')).to be false
      expect(described_class.matches?('show me my scenarios')).to be false
    end
  end

  describe '.context' do
    context 'when no docsets are installed' do
      it 'mentions that no docsets are installed' do
        context = described_class.context(user)
        expect(context).to include('No docsets installed')
        expect(context).to include('install_docset')
      end
    end

    context 'when docsets are installed' do
      before do
        Docset.create!(
          name: 'Ruby_3', display_name: 'Ruby 3', identifier: 'ruby3',
          source: 'official', status: 'ready', entry_count: 5000
        )
        Docset.create!(
          name: 'NodeJS', display_name: 'Node.js', identifier: 'nodejs',
          source: 'official', status: 'ready', entry_count: 3000
        )
      end

      it 'lists installed docsets' do
        context = described_class.context(user)
        expect(context).to include('Ruby 3')
        expect(context).to include('Node.js')
        expect(context).to include('5000')
      end

      it 'includes tool usage instructions' do
        context = described_class.context(user)
        expect(context).to include('search_docs')
        expect(context).to include('list_docsets')
      end
    end
  end
end
