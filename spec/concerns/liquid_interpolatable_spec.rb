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
  end
end
