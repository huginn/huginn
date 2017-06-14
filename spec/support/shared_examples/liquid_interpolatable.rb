require 'rails_helper'

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
      expect(@checker.interpolate_options(@checker.options, @event)).to eq({
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world"
      })
    end

    it "should work with arrays" do
      @checker.options = {"value" => ["{{variable}}", "Much array", "Hey, {{hello_world}}"]}
      expect(@checker.interpolate_options(@checker.options, @event)).to eq({
        "value" => ["hello", "Much array", "Hey, Hello world"]
      })
    end

    it "should work recursively" do
      @checker.options['hash'] = {'recursive' => "{{variable}}"}
      @checker.options['indifferent_hash'] = ActiveSupport::HashWithIndifferentAccess.new({'recursive' => "{{variable}}"})
      expect(@checker.interpolate_options(@checker.options, @event)).to eq({
          "normal" => "just some normal text",
          "variable" => "hello",
          "text" => "Some test with an embedded hello",
          "escape" => "This should be Hello+world",
          "hash" => {'recursive' => 'hello'},
          "indifferent_hash" => {'recursive' => 'hello'},
      })
    end

    it "should work for strings" do
      expect(@checker.interpolate_string("{{variable}}", @event)).to eq("hello")
      expect(@checker.interpolate_string("{{variable}} you", @event)).to eq("hello you")
    end

    it "should use local variables while in a block" do
      @checker.options['locals'] = '{{_foo_}} {{_bar_}}'

      @checker.interpolation_context.tap { |context|
        expect(@checker.interpolated['locals']).to eq(' ')

        context.stack {
          context['_foo_'] = 'This is'
          context['_bar_'] = 'great.'

          expect(@checker.interpolated['locals']).to eq('This is great.')
        }

        expect(@checker.interpolated['locals']).to eq(' ')
      }
    end

    it "should use another self object while in a block" do
      @checker.options['properties'] = '{{_foo_}} {{_bar_}}'

      expect(@checker.interpolated['properties']).to eq(' ')

      @checker.interpolate_with({ '_foo_' => 'That was', '_bar_' => 'nice.' }) {
        expect(@checker.interpolated['properties']).to eq('That was nice.')
      }

      expect(@checker.interpolated['properties']).to eq(' ')
    end
  end

  describe "liquid tags" do
    context "%credential" do
      it "should work with existing credentials" do
        expect(@checker.interpolate_string("{% credential aws_key %}", {})).to eq('2222222222-jane')
      end

      it "should not raise an exception for undefined credentials" do
        expect {
          result = @checker.interpolate_string("{% credential unknown %}", {})
          expect(result).to eq('')
        }.not_to raise_error
      end
    end

    context '%line_break' do
      it 'should convert {% line_break %} to actual line breaks' do
        expect(@checker.interpolate_string("test{% line_break %}second line", {})).to eq("test\nsecond line")
      end
    end
  end
end
