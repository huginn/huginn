require 'spec_helper'

shared_examples_for LiquidInterpolatable do
  before(:each) do
    @valid_params = {
      "normal" => "just some normal text",
      "variable" => "{{variable}}",
      "text" => "Some test with an embedded {{variable}}",
      "escape" => "This should be {{hello_world | uri_escape}}"
    }

    @checker = described_class.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :variable => 'hello', :hello_world => "Hello world"}
    @event.save!
  end

  describe "interpolating liquid templates" do
    it "should work" do
      @checker.interpolate_options(@checker.options, @event.payload).should == {
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world"
      }
    end

    it "hsould work with arrays", focus: true do
      @checker.options = {"value" => ["{{variable}}", "Much array", "Hey, {{hello_world}}"]}
      @checker.interpolate_options(@checker.options, @event.payload).should == {
        "value" => ["hello", "Much array", "Hey, Hello world"]
      }
    end

    it "should work recursively" do
      @checker.options['hash'] = {'recursive' => "{{variable}}"}
      @checker.options['indifferent_hash'] = ActiveSupport::HashWithIndifferentAccess.new({'recursive' => "{{variable}}"})
      @checker.interpolate_options(@checker.options, @event.payload).should == {
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world",
          "hash" => {'recursive' => 'hello'},
          "indifferent_hash" => {'recursive' => 'hello'},
      }
    end

    it "should work for strings" do
      @checker.interpolate_string("{{variable}}", @event.payload).should == "hello"
      @checker.interpolate_string("{{variable}} you", @event.payload).should == "hello you"
    end
  end
  describe "liquid tags" do
    it "should work with existing credentials" do
      @checker.interpolate_string("{% credential aws_key %}", {}).should == '2222222222-jane'
    end

    it "should raise an exception for undefined credentials" do
      expect {
        @checker.interpolate_string("{% credential unknown %}", {})
      }.to raise_error
    end
  end
end
