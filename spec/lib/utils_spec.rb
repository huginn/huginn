require 'spec_helper'

describe Utils do
  describe "#value_at" do
    it "returns the value at a JSON path" do
      Utils.value_at({ :foo => { :bar => :baz }}.to_json, "foo.bar").should == "baz"
      Utils.value_at({ :foo => { :bar => { :bing => 2 } }}, "foo.bar.bing").should == 2
    end

    it "returns nil when the path cannot be followed" do
      Utils.value_at({ :foo => { :bar => :baz }}, "foo.bing").should be_nil
    end
  end

  describe "#values_at" do
    it "returns arrays of matching values" do
      Utils.values_at({ :foo => { :bar => :baz }}, "foo.bar").should == %w[baz]
      Utils.values_at({ :foo => [ { :bar => :baz }, { :bar => :bing } ]}, "foo[*].bar").should == %w[baz bing]
      Utils.values_at({ :foo => [ { :bar => :baz }, { :bar => :bing } ]}, "foo[*].bar").should == %w[baz bing]
    end
  end
end