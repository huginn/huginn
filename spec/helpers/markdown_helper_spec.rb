require 'spec_helper'

describe MarkdownHelper do

  describe '#markdown' do

    it 'renders HTML from a markdown text' do
      markdown('# Header').should =~ /<h1>Header<\/h1>/
      markdown('## Header 2').should =~ /<h2>Header 2<\/h2>/
    end

  end

end
