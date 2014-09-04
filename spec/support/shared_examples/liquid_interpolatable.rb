require 'spec_helper'

shared_examples_for LiquidInterpolatable do
  before(:each) do
    @valid_params = {
      "normal" => "just some normal text",
      "variable" => "{{variable}}",
      "text" => "Some test with an embedded {{variable}}",
      "escape" => "This should be {{hello_world | uri_escape}}"
    }

    @checker = new_instance
    @checker.name = "somename"
    @checker.options = @valid_params
    @checker.user = users(:jane)

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :variable => 'hello', :hello_world => "Hello world"}
    @event.save!
  end

  describe "interpolating liquid templates" do
    it "should work" do
      @checker.interpolate_options(@checker.options, @event).should == {
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world"
      }
    end

    it "should work with arrays", focus: true do
      @checker.options = {"value" => ["{{variable}}", "Much array", "Hey, {{hello_world}}"]}
      @checker.interpolate_options(@checker.options, @event).should == {
        "value" => ["hello", "Much array", "Hey, Hello world"]
      }
    end

    it "should work recursively" do
      @checker.options['hash'] = {'recursive' => "{{variable}}"}
      @checker.options['indifferent_hash'] = ActiveSupport::HashWithIndifferentAccess.new({'recursive' => "{{variable}}"})
      @checker.interpolate_options(@checker.options, @event).should == {
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world",
          "hash" => {'recursive' => 'hello'},
          "indifferent_hash" => {'recursive' => 'hello'},
      }
    end

    it "should work for strings" do
      @checker.interpolate_string("{{variable}}", @event).should == "hello"
      @checker.interpolate_string("{{variable}} you", @event).should == "hello you"
    end

    it "should use local variables while in a block" do
      @checker.options['locals'] = '{{_foo_}} {{_bar_}}'

      @checker.interpolation_context.tap { |context|
        @checker.interpolated['locals'].should == ' '

        context.stack {
          context['_foo_'] = 'This is'
          context['_bar_'] = 'great.'

          @checker.interpolated['locals'].should == 'This is great.'
        }

        @checker.interpolated['locals'].should == ' '
      }
    end

    it "should use another self object while in a block" do
      @checker.options['properties'] = '{{_foo_}} {{_bar_}}'

      @checker.interpolated['properties'].should == ' '

      @checker.interpolate_with({ '_foo_' => 'That was', '_bar_' => 'nice.' }) {
        @checker.interpolated['properties'].should == 'That was nice.'
      }

      @checker.interpolated['properties'].should == ' '
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
