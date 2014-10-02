require 'spec_helper'
require 'nokogiri'

describe LiquidInterpolatable::Filters do
  before do
    @filter = Class.new do
      include LiquidInterpolatable::Filters
    end.new
  end

  describe 'uri_escape' do
    it 'should escape a string for use in URI' do
      @filter.uri_escape('abc:/?=').should == 'abc%3A%2F%3F%3D'
    end

    it 'should not raise an error when an operand is nil' do
      @filter.uri_escape(nil).should be_nil
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
      agent.valid?.should == false
      agent.errors[:options].first.should =~ /not properly terminated/
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
        @filter.to_xpath_roundtrip(string).should == string
      }
    end

    it 'should stringify a non-string operand' do
      @filter.to_xpath_roundtrip(nil).should == ''
      @filter.to_xpath_roundtrip(1).should == '1'
    end
  end

  describe 'to_uri' do
    before do
      @agent = Agents::InterpolatableAgent.new(name: "test", options: { 'foo' => '{% assign u = s | to_uri %}{{ u.path }}' })
      @agent.interpolation_context['s'] = 'http://example.com/dir/1?q=test'
    end

    it 'should parse an abosule URI' do
      @filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1').should == URI('http://example.net/index.html')
    end

    it 'should parse an abosule URI with a base URI specified' do
      @filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1').should == URI('http://example.net/index.html')
    end

    it 'should parse a relative URI with a base URI specified' do
      @filter.to_uri('foo/index.html', 'http://example.com/dir/1').should == URI('http://example.com/dir/foo/index.html')
    end

    it 'should parse an abosule URI with a base URI specified' do
      @filter.to_uri('http://example.net/index.html', 'http://example.com/dir/1').should == URI('http://example.net/index.html')
    end

    it 'should stringify a non-string operand' do
      @filter.to_uri(123, 'http://example.com/dir/1').should == URI('http://example.com/dir/123')
    end

    it 'should return a URI value in interpolation' do
      @agent.interpolated['foo'].should == '/dir/1'
    end

    it 'should return a URI value resolved against a base URI in interpolation' do
      @agent.options['foo'] = '{% assign u = s | to_uri:"http://example.com/dir/1" %}{{ u.path }}'
      @agent.interpolation_context['s'] = 'foo/index.html'
      @agent.interpolated['foo'].should == '/dir/foo/index.html'
    end
  end
end
