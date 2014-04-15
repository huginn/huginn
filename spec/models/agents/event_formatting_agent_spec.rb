require 'spec_helper'

describe Agents::EventFormattingAgent do
  before do
    @valid_params = {
        :name => "somename",
        :options => {
            :instructions => {
                :message => "Received <$.content.text.*> from <$.content.name> .",
                :subject => "Weather looks like <$.conditions> according to the forecast at <$.pretty_date.time>"
            },
            :mode => "clean",
            :matchers => [
                {
                    :path => "$.date.pretty",
                    :regexp => "\\A(?<time>\\d\\d:\\d\\d [AP]M [A-Z]+)",
                    :to => "pretty_date",
                },
            ],
            :skip_agent => "false",
            :skip_created_at => "false"
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
  end

  describe "#receive" do
    it "should accept clean mode" do
      @checker.receive([@event])
      Event.last.payload[:content].should == nil
    end

    it "should accept merge mode" do
      @checker.options[:mode] = "merge"
      @checker.receive([@event])
      Event.last.payload[:content].should_not == nil
    end

    it "should accept skip_agent" do
      @checker.receive([@event])
      Event.last.payload[:agent].should == "WeatherAgent"
      @checker.options[:skip_agent] = "true"
      @checker.receive([@event])
      Event.last.payload[:agent].should == nil
    end

    it "should accept skip_created_at" do
      @checker.receive([@event])
      Event.last.payload[:created_at].should_not == nil
      @checker.options[:skip_created_at] = "true"
      @checker.receive([@event])
      Event.last.payload[:created_at].should == nil
    end

    it "should handle JSONPaths in instructions" do
      @checker.receive([@event])
      Event.last.payload[:message].should == "Received Some Lorem Ipsum from somevalue ."
    end

    it "should handle matchers and JSONPaths in instructions" do
      @checker.receive([@event])
      Event.last.payload[:subject].should == "Weather looks like someothervalue according to the forecast at 10:00 PM EST"
    end

    it "should allow escaping" do
      @event.payload[:content][:name] = "escape this!?"
      @event.save!
      @checker.options[:instructions][:message] = "Escaped: <escape $.content.name>\nNot escaped: <$.content.name>"
      @checker.save!
      @checker.receive([@event])
      Event.last.payload[:message].should == "Escaped: escape+this%21%3F\nNot escaped: escape this!?"
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

      lambda {
        @checker.receive([event2, event1])
      }.should change { Event.count }.by(2)
    end
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of instructions" do
      @checker.options[:instructions] = ""
      @checker.should_not be_valid
    end

    it "should validate type of matchers" do
      @checker.options[:matchers] = ""
      @checker.should_not be_valid
      @checker.options[:matchers] = {}
      @checker.should_not be_valid
    end

    it "should validate the contents of matchers" do
      @checker.options[:matchers] = [
        {}
      ]
      @checker.should_not be_valid
      @checker.options[:matchers] = [
        { :regexp => "(not closed", :path => "text" }
      ]
      @checker.should_not be_valid
      @checker.options[:matchers] = [
        { :regexp => "(closed)", :path => "text", :to => "foo" }
      ]
      @checker.should be_valid
    end

    it "should validate presence of mode" do
      @checker.options[:mode] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of skip_agent" do
      @checker.options[:skip_agent] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of skip_created_at" do
      @checker.options[:skip_created_at] = ""
      @checker.should_not be_valid
    end
  end
end
