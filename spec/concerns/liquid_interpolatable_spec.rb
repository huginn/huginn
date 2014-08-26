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
  end
end
