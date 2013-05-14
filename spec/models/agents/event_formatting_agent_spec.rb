require 'spec_helper'

describe Agents::EventFormattingAgent do
    before do
        @valid_params = {
            :name => "somename",
            :options => {
                :instructions => {
                    :message => "Received <$.content.text.*> from <$.content.name> .",
                    :subject => "Weather looks like <$.conditions>"
                },
                :mode => "clean",
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
                :name => "somevalue"
            },
            :conditions => "someothervalue" 
        }
    end

    describe "#receive" do
        it "checks if clean mode is working fine" do
            @checker.receive([@event])
            Event.last.payload[:content].should == nil
        end

        it "checks if merge mode is working fine" do
            @checker.options[:mode] = "merge"
            @checker.receive([@event])
            Event.last.payload[:content].should_not == nil
        end

        it "checks if skip_agent is working fine" do
            @checker.receive([@event])
            Event.last.payload[:agent].should == "WeatherAgent"
            @checker.options[:skip_agent] = "true"
            @checker.receive([@event])
            Event.last.payload[:agent].should == nil
        end

        it "checks if skip_created_at is working fine" do
            @checker.receive([@event])
            Event.last.payload[:created_at].should_not == nil
            @checker.options[:skip_created_at] = "true"
            @checker.receive([@event])
            Event.last.payload[:created_at].should == nil
        end

        it "checks if instructions are working fine" do
            @checker.receive([@event])
            Event.last.payload[:message].should == "Received Some Lorem Ipsum from somevalue ."
            Event.last.payload[:subject].should == "Weather looks like someothervalue"
        end

        it "checks if it can handle multiple events" do
            event1 = Event.new
            event1.agent = agents(:bob_weather_agent)
            event1.payload =  {
            :content => {
                :text => "Some Lorem Ipsum",
                :name => "somevalue"
                },
            :conditions => "someothervalue" 
            }

            event2 = Event.new
            event2.agent = agents(:bob_weather_agent)
            event2.payload =  {
            :content => {
                :text => "Some Lorem Ipsum",
                :name => "somevalue"
                },
            :conditions => "someothervalue" 
            }

        lambda {
            @checker.receive([event2,event1])
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