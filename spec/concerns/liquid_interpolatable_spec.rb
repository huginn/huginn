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

    it 'should stringize a non-string operand' do
      @filter.to_xpath_roundtrip(nil).should == ''
      @filter.to_xpath_roundtrip(1).should == '1'
    end
  end
end
