require 'rails_helper'

describe MarkdownHelper do

  describe '#markdown' do

    it 'renders HTML from a markdown text' do
      expect(markdown('# Header')).to match(/<h1>Header<\/h1>/)
      expect(markdown('## Header 2')).to match(/<h2>Header 2<\/h2>/)
    end

  end

end
