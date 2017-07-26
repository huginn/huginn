require 'rails_helper'

describe Agents::EventFormattingAgent do
  before do
    @valid_params = {
        :name => "somename",
        :options => {
            :instructions => {
                :message => "Received {{content.text}} from {{content.name}} .",
                :subject => "Weather looks like {{conditions}} according to the forecast at {{pretty_date.time}}",
                :timezone => "{{timezone}}",
                :agent => "{{agent.type}}",
                :created_at => "{{created_at}}",
                :created_at_iso => "{{created_at | date:'%FT%T%:z'}}",
            },
            :mode => "clean",
            :matchers => [
                {
                    :path => "{{date.pretty}}",
                    :regexp => "\\A(?<time>\\d\\d:\\d\\d [AP]M [A-Z]+)",
                    :to => "pretty_date",
                },
                {
                    :path => "{{pretty_date.time}}",
                    :regexp => "(?<timezone>[A-Z]+)\\z",
                },
            ],
        }
    }
    @checker = Agents::EventFormattingAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.created_at = Time.now
    @event.payload = {
        :content => {
            :text => "Some Lorem Ipsum",
            :name => "somevalue",
        },
        :date => {
            :epoch => "1357959600",
            :pretty => "10:00 PM EST on January 11, 2013"
        },
        :conditions => "someothervalue"
    }

    @event2 = Event.new
    @event2.agent = agents(:jane_weather_agent)
    @event2.created_at = Time.now
    @event2.payload = {
        :content => {
            :text => "Some Lorem Ipsum 2",
            :name => "somevalue2",
        },
        :date => {
            :epoch => "1366372800",
            :pretty => "08:00 AM EDT on April 19, 2013"
        },
        :conditions => "someothervalue2"
    }
  end

  describe "#receive" do
    it "should accept clean mode" do
      @checker.receive([@event])
      expect(Event.last.payload[:content]).to eq(nil)
    end

    it "should accept merge mode" do
      @checker.options[:mode] = "merge"
      @checker.receive([@event])
      expect(Event.last.payload[:content]).not_to eq(nil)
    end

    it "should handle Liquid templating in mode" do
      @checker.options[:mode] = "{{'merge'}}"
      @checker.receive([@event])
      expect(Event.last.payload[:content]).not_to eq(nil)
    end

    it "should handle Liquid templating in instructions" do
      @checker.receive([@event])
      expect(Event.last.payload[:message]).to eq("Received Some Lorem Ipsum from somevalue .")
      expect(Event.last.payload[:agent]).to eq("WeatherAgent")
      expect(Event.last.payload[:created_at]).to eq(@event.created_at.to_s)
      expect(Event.last.payload[:created_at_iso]).to eq(@event.created_at.iso8601)
    end

    it "should handle matchers and Liquid templating in instructions" do
      expect {
        @checker.receive([@event, @event2])
      }.to change { Event.count }.by(2)

      formatted_event1, formatted_event2 = Event.last(2)

      expect(formatted_event1.payload[:subject]).to eq("Weather looks like someothervalue according to the forecast at 10:00 PM EST")
      expect(formatted_event1.payload[:timezone]).to eq("EST")
      expect(formatted_event2.payload[:subject]).to eq("Weather looks like someothervalue2 according to the forecast at 08:00 AM EDT")
      expect(formatted_event2.payload[:timezone]).to eq("EDT")
    end

    it "should not fail if no matchers are defined" do
      @checker.options.delete(:matchers)

      expect {
        @checker.receive([@event, @event2])
      }.to change { Event.count }.by(2)

      formatted_event1, formatted_event2 = Event.last(2)

      expect(formatted_event1.payload[:subject]).to eq("Weather looks like someothervalue according to the forecast at ")
      expect(formatted_event1.payload[:timezone]).to eq("")
      expect(formatted_event2.payload[:subject]).to eq("Weather looks like someothervalue2 according to the forecast at ")
      expect(formatted_event2.payload[:timezone]).to eq("")
    end

    it "should allow escaping" do
      @event.payload[:content][:name] = "escape this!?"
      @event.save!
      @checker.options[:instructions][:message] = "Escaped: {{content.name | uri_escape}}\nNot escaped: {{content.name}}"
      @checker.save!
      @checker.receive([@event])
      expect(Event.last.payload[:message]).to eq("Escaped: escape+this%21%3F\nNot escaped: escape this!?")
    end

    it "should handle multiple events" do
      event1 = Event.new
      event1.agent = agents(:bob_weather_agent)
      event1.payload = {
          :content => {
              :text => "Some Lorem Ipsum",
              :name => "somevalue"
          },
          :conditions => "someothervalue"
      }

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = {
          :content => {
              :text => "Some Lorem Ipsum",
              :name => "somevalue"
          },
          :conditions => "someothervalue"
      }

      expect {
        @checker.receive([event2, event1])
      }.to change { Event.count }.by(2)
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of instructions" do
      @checker.options[:instructions] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate type of matchers" do
      @checker.options[:matchers] = ""
      expect(@checker).not_to be_valid
      @checker.options[:matchers] = {}
      expect(@checker).not_to be_valid
    end

    it "should validate the contents of matchers" do
      @checker.options[:matchers] = [
        {}
      ]
      expect(@checker).not_to be_valid
      @checker.options[:matchers] = [
        { :regexp => "(not closed", :path => "text" }
      ]
      expect(@checker).not_to be_valid
      @checker.options[:matchers] = [
        { :regexp => "(closed)", :path => "text", :to => "foo" }
      ]
      expect(@checker).to be_valid
    end

    it "should validate presence of mode" do
      @checker.options[:mode] = ""
      expect(@checker).not_to be_valid
    end

    it "requires mode to be 'clean' or 'merge'" do
      @checker.options['mode'] = 'what?'
      expect(@checker).not_to be_valid

      @checker.options['mode'] = 'clean'
      expect(@checker).to be_valid

      @checker.options['mode'] = 'merge'
      expect(@checker).to be_valid

      @checker.options['mode'] = :clean
      expect(@checker).to be_valid

      @checker.options['mode'] = :merge
      expect(@checker).to be_valid

      @checker.options['mode'] = '{{somekey}}'
      expect(@checker).to be_valid
    end
  end
end
