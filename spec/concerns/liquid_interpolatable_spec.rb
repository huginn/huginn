require 'rails_helper'
require 'nokogiri'

describe LiquidInterpolatable::Filters do
  before do
    @filter = Class.new do
      include LiquidInterpolatable::Filters
    end.new
  end

  describe 'uri_escape' do
    it 'should escape a string for use in URI' do
      expect(@filter.uri_escape('abc:/?=')).to eq('abc%3A%2F%3F%3D')
    end

    it 'should not raise an error when an operand is nil' do
      expect(@filter.uri_escape(nil)).to be_nil
    end
  end

  describe 'validations' do
    class Agents::InterpolatableAgent < Agent
      include LiquidInterpolatable

      def check
        create_event :payload => {}
      end

      def validate_options
        interpolated['foo']
      end
    end

    it "should finish without raising an exception" do
      agent = Agents::InterpolatableAgent.new(name: "test", options: { 'foo' => '{{bar}' })
      expect(agent.valid?).to eq(false)
      expect(agent.errors[:options].first).to match(/not properly terminated/)
    end
  end

  describe 'unescape' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'should unescape basic HTML entities' do
      agent.interpolation_context['something'] = '&#39;&lt;foo&gt; &amp; bar&#x27;'
      agent.options['cleaned'] = '{{ something | unescape }}'
      expect(agent.interpolated['cleaned']).to eq("'<foo> & bar'")
    end
  end

  describe "json" do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'serializes data to json' do
      agent.interpolation_context['something'] = {foo: 'bar'}
      agent.options['cleaned'] = '{{ something | json }}'
      expect(agent.interpolated['cleaned']).to eq('{"foo":"bar"}')
    end
  end

  describe 'to_xpath' do
    before do
      def @filter.to_xpath_roundtrip(string)
        Nokogiri::XML('').xpath(to_xpath(string))
      end
    end

    it 'should escape a string for use in XPath expression' do
      [
        %q{abc}.freeze,
        %q{'a"bc'dfa""fds''fa}.freeze,
      ].each { |string|
        expect(@filter.to_xpath_roundtrip(string)).to eq(string)
      }
    end

    it 'should stringify a non-string operand' do
      expect(@filter.to_xpath_roundtrip(nil)).to eq('')
      expect(@filter.to_xpath_roundtrip(1)).to eq('1')
    end
  end

  describe 'to_uri' do
    before do
      @agent = Agents::InterpolatableAgent.new(name: "test", options: { 'foo' => '{% assign u = s | to_uri %}{{ u.path }}' })
      @agent.interpolation_context['s'] = 'http://example.com/dir/1?q=test'
    end

    it 'should parse an abosule URI' do
      expect(@filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.net/index.html'))
    end

    it 'should parse an abosule URI with a base URI specified' do
      expect(@filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.net/index.html'))
    end

    it 'should parse a relative URI with a base URI specified' do
      expect(@filter.to_uri('foo/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.com/dir/foo/index.html'))
    end

    it 'should parse an abosule URI with a base URI specified' do
      expect(@filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.net/index.html'))
    end

    it 'should stringify a non-string operand' do
      expect(@filter.to_uri(123, 'http://example.com/dir/1')).to eq(URI('http://example.com/dir/123'))
    end

    it 'should return a URI value in interpolation' do
      expect(@agent.interpolated['foo']).to eq('/dir/1')
    end

    it 'should return a URI value resolved against a base URI in interpolation' do
      @agent.options['foo'] = '{% assign u = s | to_uri:"http://example.com/dir/1" %}{{ u.path }}'
      @agent.interpolation_context['s'] = 'foo/index.html'
      expect(@agent.interpolated['foo']).to eq('/dir/foo/index.html')
    end
  end

  describe 'uri_expand' do
    before do
      stub_request(:head, 'https://t.co.x/aaaa').
        to_return(status: 301, headers: { Location: 'https://bit.ly.x/bbbb' })
      stub_request(:head, 'https://bit.ly.x/bbbb').
        to_return(status: 301, headers: { Location: 'http://tinyurl.com.x/cccc' })
      stub_request(:head, 'http://tinyurl.com.x/cccc').
        to_return(status: 301, headers: { Location: 'http://www.example.com/welcome' })
      stub_request(:head, 'http://www.example.com/welcome').
        to_return(status: 200)

      (1..5).each do |i|
        stub_request(:head, "http://2many.x/#{i}").
          to_return(status: 301, headers: { Location: "http://2many.x/#{i+1}" })
      end
      stub_request(:head, 'http://2many.x/6').
        to_return(status: 301, headers: { 'Content-Length' => '5' })
    end

    it 'should handle inaccessible URIs' do
      expect(@filter.uri_expand(nil)).to eq('')
      expect(@filter.uri_expand('')).to eq('')
      expect(@filter.uri_expand(5)).to eq('5')
      expect(@filter.uri_expand([])).to eq('[]')
      expect(@filter.uri_expand({})).to eq('{}')
      expect(@filter.uri_expand(URI('/'))).to eq('/')
      expect(@filter.uri_expand(URI('http:google.com'))).to eq('http:google.com')
      expect(@filter.uri_expand(URI('http:/google.com'))).to eq('http:/google.com')
      expect(@filter.uri_expand(URI('ftp://ftp.freebsd.org/pub/FreeBSD/README.TXT'))).to eq('ftp://ftp.freebsd.org/pub/FreeBSD/README.TXT')
    end

    it 'should follow redirects' do
      expect(@filter.uri_expand('https://t.co.x/aaaa')).to eq('http://www.example.com/welcome')
    end

    it 'should respect the limit for the number of redirects' do
      expect(@filter.uri_expand('http://2many.x/1')).to eq('http://2many.x/1')
      expect(@filter.uri_expand('http://2many.x/1', 6)).to eq('http://2many.x/6')
    end

    it 'should detect a redirect loop' do
      stub_request(:head, 'http://bad.x/aaaa').
        to_return(status: 301, headers: { Location: 'http://bad.x/bbbb' })
      stub_request(:head, 'http://bad.x/bbbb').
        to_return(status: 301, headers: { Location: 'http://bad.x/aaaa' })

      expect(@filter.uri_expand('http://bad.x/aaaa')).to eq('http://bad.x/aaaa')
    end

    it 'should be able to handle an FTP URL' do
      stub_request(:head, 'http://downloads.x/aaaa').
        to_return(status: 301, headers: { Location: 'http://downloads.x/download?file=aaaa.zip' })
      stub_request(:head, 'http://downloads.x/download').
        with(query: { file: 'aaaa.zip' }).
        to_return(status: 301, headers: { Location: 'ftp://downloads.x/pub/aaaa.zip' })

      expect(@filter.uri_expand('http://downloads.x/aaaa')).to eq('ftp://downloads.x/pub/aaaa.zip')
    end

    describe 'used in interpolation' do
      before do
        @agent = Agents::InterpolatableAgent.new(name: "test")
      end

      it 'should follow redirects' do
        @agent.interpolation_context['short_url'] = 'https://t.co.x/aaaa'
        @agent.options['long_url'] = '{{ short_url | uri_expand }}'
        expect(@agent.interpolated['long_url']).to eq('http://www.example.com/welcome')
      end

      it 'should respect the limit for the number of redirects' do
        @agent.interpolation_context['short_url'] = 'http://2many.x/1'
        @agent.options['long_url'] = '{{ short_url | uri_expand }}'
        expect(@agent.interpolated['long_url']).to eq('http://2many.x/1')

        @agent.interpolation_context['short_url'] = 'http://2many.x/1'
        @agent.options['long_url'] = '{{ short_url | uri_expand:6 }}'
        expect(@agent.interpolated['long_url']).to eq('http://2many.x/6')
      end
    end
  end

  describe 'regex_replace_first' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'should replace the first occurrence of a string using regex' do
      agent.interpolation_context['something'] = 'foobar foobar'
      agent.options['cleaned'] = '{{ something | regex_replace_first: "\S+bar", "foobaz"  }}'
      expect(agent.interpolated['cleaned']).to eq('foobaz foobar')
    end

    it 'should support escaped characters' do
      agent.interpolation_context['something'] = "foo\\1\n\nfoo\\bar\n\nfoo\\baz"
      agent.options['test'] = "{{ something | regex_replace_first: '\\\\(\\w{2,})', '\\1\\\\' | regex_replace_first: '\\n+', '\\n'  }}"
      expect(agent.interpolated['test']).to eq("foo\\1\nfoobar\\\n\nfoo\\baz")
    end
  end

  describe 'regex_replace' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'should replace the all occurrences of a string using regex' do
      agent.interpolation_context['something'] = 'foobar foobar'
      agent.options['cleaned'] = '{{ something | regex_replace: "\S+bar", "foobaz"  }}'
      expect(agent.interpolated['cleaned']).to eq('foobaz foobaz')
    end

    it 'should support escaped characters' do
      agent.interpolation_context['something'] = "foo\\1\n\nfoo\\bar\n\nfoo\\baz"
      agent.options['test'] = "{{ something | regex_replace: '\\\\(\\w{2,})', '\\1\\\\' | regex_replace: '\\n+', '\\n'  }}"
      expect(agent.interpolated['test']).to eq("foo\\1\nfoobar\\\nfoobaz\\")
    end
  end

  describe 'regex_replace_first block' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'should replace the first occurrence of a string using regex' do
      agent.interpolation_context['something'] = 'foobar zoobar'
      agent.options['cleaned'] = '{% regex_replace_first "(?<word>\S+)(?<suffix>bar)" in %}{{ something }}{% with %}{{ word | upcase }}{{ suffix }}{% endregex_replace_first %}'
      expect(agent.interpolated['cleaned']).to eq('FOObar zoobar')
    end

    it 'should be able to take a pattern in a variable' do
      agent.interpolation_context['something'] = 'foobar zoobar'
      agent.interpolation_context['pattern'] = "(?<word>\\S+)(?<suffix>bar)"
      agent.options['cleaned'] = '{% regex_replace_first pattern in %}{{ something }}{% with %}{{ word | upcase }}{{ suffix }}{% endregex_replace_first %}'
      expect(agent.interpolated['cleaned']).to eq('FOObar zoobar')
    end

    it 'should define a variable named "match" in a "with" block' do
      agent.interpolation_context['something'] = 'foobar zoobar'
      agent.interpolation_context['pattern'] = "(?<word>\\S+)(?<suffix>bar)"
      agent.options['cleaned'] = '{% regex_replace_first pattern in %}{{ something }}{% with %}{{ match.word | upcase }}{{ match["suffix"] }}{% endregex_replace_first %}'
      expect(agent.interpolated['cleaned']).to eq('FOObar zoobar')
    end
  end

  describe 'regex_replace block' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'should replace the all occurrences of a string using regex' do
      agent.interpolation_context['something'] = 'foobar zoobar'
      agent.options['cleaned'] = '{% regex_replace "(?<word>\S+)(?<suffix>bar)" in %}{{ something }}{% with %}{{ word | upcase }}{{ suffix }}{% endregex_replace %}'
      expect(agent.interpolated['cleaned']).to eq('FOObar ZOObar')
    end
  end
end
