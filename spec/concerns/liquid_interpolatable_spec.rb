require 'spec_helper'

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
end
