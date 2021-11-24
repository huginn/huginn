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

    it 'should parse an absolute URI' do
      expect(@filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.net/index.html'))
    end

    it 'should parse an absolute URI with a base URI specified' do
      expect(@filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.net/index.html'))
    end

    it 'should parse a relative URI with a base URI specified' do
      expect(@filter.to_uri('foo/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.com/dir/foo/index.html'))
    end

    it 'should parse an absolute URI with a base URI specified' do
      expect(@filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1')).to eq(URI('http://example.net/index.html'))
    end

    it 'should stringify a non-string operand' do
      expect(@filter.to_uri(123, 'http://example.com/dir/1')).to eq(URI('http://example.com/dir/123'))
    end

    it 'should normalize a URL' do
      expect(@filter.to_uri('a[]', 'http://example.com/dir/1')).to eq(URI('http://example.com/dir/a%5B%5D'))
    end

    it 'should return a URI value in interpolation' do
      expect(@agent.interpolated['foo']).to eq('/dir/1')
    end

    it 'should return a URI value resolved against a base URI in interpolation' do
      @agent.options['foo'] = '{% assign u = s | to_uri:"http://example.com/dir/1" %}{{ u.path }}'
      @agent.interpolation_context['s'] = 'foo/index.html'
      expect(@agent.interpolated['foo']).to eq('/dir/foo/index.html')
    end

    it 'should normalize a URI value if an empty base URI is given' do
      @agent.options['foo'] = '{{ u | to_uri: b }}'
      @agent.interpolation_context['u'] = "\u{3042}"
      @agent.interpolation_context['b'] = ""
      expect(@agent.interpolated['foo']).to eq('%E3%81%82')
      @agent.interpolation_context['b'] = nil
      expect(@agent.interpolated['foo']).to eq('%E3%81%82')
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
      expect(@filter.uri_expand([])).to eq('%5B%5D')
      expect(@filter.uri_expand({})).to eq('%7B%7D')
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

  context 'as_object' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'returns an array that was splitted in liquid tags' do
      agent.interpolation_context['something'] = 'test,string,abc'
      agent.options['array'] = "{{something | split: ',' | as_object}}"
      expect(agent.interpolated['array']).to eq(['test', 'string', 'abc'])
    end

    it 'returns an object that was not modified in liquid' do
      agent.interpolation_context['something'] = {'nested' => {'abc' => 'test'}}
      agent.options['object'] = "{{something.nested | as_object}}"
      expect(agent.interpolated['object']).to eq({"abc" => 'test'})
    end

    context 'as_json' do
      def ensure_safety(obj)
        JSON.parse(JSON.dump(obj))
      end

      it 'it converts "complex" objects' do
        agent.interpolation_context['something'] = {'nested' => Service.new}
        agent.options['object'] = "{{something | as_object}}"
        expect(agent.interpolated['object']).to eq({'nested'=> ensure_safety(Service.new.as_json)})
      end

      it 'works with AgentDrops' do
        agent.interpolation_context['something'] = agent
        agent.options['object'] = "{{something | as_object}}"
        expect(agent.interpolated['object']).to eq(ensure_safety(agent.to_liquid.as_json.stringify_keys))
      end

      it 'works with EventDrops' do
        event = Event.new(payload: {some: 'payload'}, agent: agent, created_at: Time.now)
        agent.interpolation_context['something'] = event
        agent.options['object'] = "{{something | as_object}}"
        expect(agent.interpolated['object']).to eq(ensure_safety(event.to_liquid.as_json.stringify_keys))
      end

      it 'works with MatchDataDrops' do
        match = "test string".match(/\A(?<word>\w+)\s(.+?)\z/)
        agent.interpolation_context['something'] = match
        agent.options['object'] = "{{something | as_object}}"
        expect(agent.interpolated['object']).to eq(ensure_safety(match.to_liquid.as_json.stringify_keys))
      end

      it 'works with URIDrops' do
        uri = URI.parse("https://google.com?q=test")
        agent.interpolation_context['something'] = uri
        agent.options['object'] = "{{something | as_object}}"
        expect(agent.interpolated['object']).to eq(ensure_safety(uri.to_liquid.as_json.stringify_keys))
      end
    end
  end

  describe 'rebase_hrefs' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    let(:fragment) { <<HTML }
<ul>
  <li>
    <a href="downloads/file1"><img src="/images/iconA.png" srcset="/images/iconA.png 1x, /images/iconA@2x.png 2x">file1</a>
  </li>
  <li>
    <a href="downloads/file2"><img src="/images/iconA.png" srcset="/images/iconA.png 1x, /images/iconA@2x.png 2x">file2</a>
  </li>
  <li>
    <a href="downloads/file3"><img src="/images/iconB.png" srcset="/images/iconB.png 1x, /images/iconB@2x.png 2x">file3</a>
  </li>
</ul>
HTML

    let(:replaced_fragment) { <<HTML }
<ul>
  <li>
    <a href="http://example.com/support/downloads/file1"><img src="http://example.com/images/iconA.png" srcset="http://example.com/images/iconA.png 1x, http://example.com/images/iconA@2x.png 2x">file1</a>
  </li>
  <li>
    <a href="http://example.com/support/downloads/file2"><img src="http://example.com/images/iconA.png" srcset="http://example.com/images/iconA.png 1x, http://example.com/images/iconA@2x.png 2x">file2</a>
  </li>
  <li>
    <a href="http://example.com/support/downloads/file3"><img src="http://example.com/images/iconB.png" srcset="http://example.com/images/iconB.png 1x, http://example.com/images/iconB@2x.png 2x">file3</a>
  </li>
</ul>
HTML

    it 'rebases relative URLs in a fragment' do
      agent.interpolation_context['content'] = fragment
      agent.options['template'] = "{{ content | rebase_hrefs: 'http://example.com/support/files.html' }}"
      expect(agent.interpolated['template']).to eq(replaced_fragment)
    end
  end

  describe 'digest filters' do
    let(:agent) { Agents::InterpolatableAgent.new(name: "test") }

    it 'computes digest values from string input' do
      agent.interpolation_context['value'] = 'Huginn'
      agent.interpolation_context['key'] = 'Muninn'

      agent.options['template'] = "{{ value | md5 }}"
      expect(agent.interpolated['template']).to eq('5fca9fe120027bc87fa9923cc926f8fe')

      agent.options['template'] = "{{ value | sha1 }}"
      expect(agent.interpolated['template']).to eq('647d81f6dae6ff474cdcef3e9b74f038206af680')

      agent.options['template'] = "{{ value | sha256 }}"
      expect(agent.interpolated['template']).to eq('62c6099ec14502176974aadf0991525f50332ba552500556fea583ffdf0ba076')

      agent.options['template'] = "{{ value | hmac_sha1: key }}"
      expect(agent.interpolated['template']).to eq('9bd7cdebac134e06ba87258c28d2deea431407ac')

      agent.options['template'] = "{{ value | hmac_sha256: key }}"
      expect(agent.interpolated['template']).to eq('38b98bc2625a8cac33369f6204e784482be5e172b242699406270856a841d1ec')
    end
  end

  describe 'group_by' do
    let(:events) do
      [
        { "date" => "2019-07-30", "type" => "Snap" },
        { "date" => "2019-07-30", "type" => "Crackle" },
        { "date" => "2019-07-29", "type" => "Pop" },
        { "date" => "2019-07-29", "type" => "Bam" },
        { "date" => "2019-07-29", "type" => "Pow" },
      ]
    end

    it "should group an enumerable by the given attribute" do
      expect(@filter.group_by(events, "date")).to eq(
        [
          {
            "name" => "2019-07-30", "items" => [
              { "date" => "2019-07-30", "type" => "Snap" },
              { "date" => "2019-07-30", "type" => "Crackle" }
            ]
          },
          {
            "name" => "2019-07-29", "items" => [
              { "date" => "2019-07-29", "type" => "Pop" },
              { "date" => "2019-07-29", "type" => "Bam" },
              { "date" => "2019-07-29", "type" => "Pow" }
            ]
          }
        ]
      )
    end

    it "should leave non-groupables alone" do
      expect(@filter.group_by("some string", "anything")).to eq("some string")
    end
  end
end
