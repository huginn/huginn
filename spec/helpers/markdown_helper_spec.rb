require 'rails_helper'

describe MarkdownHelper do

  describe '#markdown' do

    it 'renders HTML from a markdown text' do
      expect(markdown('# Header')).to match(/<h1>Header<\/h1>/)
      expect(markdown('## Header 2')).to match(/<h2>Header 2<\/h2>/)
    end

    it 'returns an html_safe string' do
      expect(markdown('text')).to be_html_safe
    end

    it 'keeps tables and their alignment' do
      html = markdown("| a | b |\n|---|--:|\n| 1 | 2 |")
      expect(html).to match(/<table>.*<th>a<\/th>.*<td>1<\/td>.*<\/table>/m)
      expect(html).to include('<td style="text-align:right;">2</td>')
    end

    it 'scrubs unsafe CSS from style attributes' do
      html = markdown('<p style="color:red;position:fixed;width:expression(alert(1))">text</p>')
      expect(Nokogiri(html).at('p')['style']).to eq('color:red;')
    end

    it 'keeps url() values with allowed URIs in style attributes' do
      html = markdown('<p style="background:url(http://example.com/a.png);color:red">text</p>')
      expect(Nokogiri(html).at('p')['style']).to eq('background:url("http://example.com/a.png");color:red;')

      html = markdown(%q{<p style="background-image: url( 'https://example.com/a.png' ) !important">text</p>})
      expect(Nokogiri(html).at('p')['style']).to eq('background-image:url("https://example.com/a.png") !important;')

      html = markdown('<p style="background-image:url(data:image/png;base64,AAAA)">text</p>')
      expect(Nokogiri(html).at('p')['style']).to eq('background-image:url("data:image/png;base64,AAAA");')

      html = markdown('<p style="background-image:url(data:image/svg+xml;base64,AAAA)">text</p>')
      expect(Nokogiri(html).at('p')['style']).to eq('background-image:url("data:image/svg+xml;base64,AAAA");')
    end

    it 'drops url() values with disallowed URIs' do
      html = markdown('<p style="background:url(javascript:alert(1));color:red">text</p>')
      expect(Nokogiri(html).at('p')['style']).to eq('color:red;')

      html = markdown('<p style="background-image:url(data:text/plain,x)">text</p>')
      expect(Nokogiri(html).at('p')['style']).to be_blank

      html = markdown(%q{<p style="background-image:url('data:text/html,<script>alert(1)</script>')">text</p>})
      expect(Nokogiri(html).at('p')['style']).to be_blank
    end

    it 'drops url() values in disallowed properties' do
      html = markdown('<p style="behavior:url(http://example.com/x.htc)">text</p>')
      expect(Nokogiri(html).at('p')['style']).to be_blank
    end

    it 'strips script elements' do
      html = markdown("text\n\n<script>alert(1)</script>\n\nmore")
      expect(html).not_to include('<script')
      expect(html).not_to include('alert(1)')
    end

    it 'strips event handler attributes from block HTML' do
      html = markdown("<div onclick=\"alert(1)\">text</div>")
      expect(html).to include('<div>text</div>')
      expect(html).not_to include('onclick')
    end

    it 'strips event handler attributes from inline HTML' do
      html = markdown("an <img src=\"x\" onerror=\"alert(1)\"> image")
      expect(html).not_to include('onerror')
    end

    it 'drops javascript: links' do
      html = markdown("[click](javascript:alert(1))")
      expect(html).not_to include('javascript:')
      expect(html).to include('click')
    end

  end

end
