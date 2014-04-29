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
      @checker.send(:interpolate_options, @checker.options, @event.payload).should == {
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world"
      }
    end

    it "should work for strings" do
      @checker.send(:interpolate_string, "{{variable}}", @event.payload).should == "hello"
      @checker.send(:interpolate_string, "{{variable}} you", @event.payload).should == "hello you"
    end
  end
end
