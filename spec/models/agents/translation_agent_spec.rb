require 'rails_helper'

describe Agents::TranslationAgent do
    before do
        @valid_params = {
            :name    => "somename",
            :options => {           
                :client_id     => "xxxxxx",
                :client_secret => "xxxxxx" ,
                :to            => "fi",
                :expected_receive_period_in_days => 1,
                :content       => {
                    :text => "{{message}}",
                    :content => "{{xyz}}"
                }
            }
        }

        @checker = Agents::TranslationAgent.new(@valid_params)
        @checker.user = users(:jane)
        @checker.save!

        @event = Event.new
        @event.agent = agents(:jane_weather_agent)
        @event.payload = {
            :message => "somevalue",
            :xyz => "someothervalue"
        }

        stub_request(:any, /microsoft/).to_return(:body => "response", :status => 200)
        stub_request(:any, /windows/).to_return(:body => JSON.dump({
            :access_token => 'xxx'}), :status => 200)

    end

    describe "#receive" do
        it "checks if it can handle multiple events" do
            event1 = Event.new
            event1.agent = agents(:bob_weather_agent)
            event1.payload = {
                :xyz => "value1",
                :message => "value2"
            }

            expect {
                @checker.receive([@event,event1])
            }.to change { Event.count }.by(2)
        end
    end

    describe "#working?" do
        it "checks if events have been received within expected receive period" do
            expect(@checker).not_to be_working
            Agents::TranslationAgent.async_receive @checker.id, [@event.id]
            expect(@checker.reload).to be_working
            two_days_from_now = 2.days.from_now
            stub(Time).now { two_days_from_now }  
            expect(@checker.reload).not_to be_working
        end
    end

    describe "validation" do
        before do
            expect(@checker).to be_valid
        end

        it "should validate presence of content key" do
            @checker.options[:content] = nil
            expect(@checker).not_to be_valid
        end

        it "should validate presence of expected_receive_period_in_days key" do
            @checker.options[:expected_receive_period_in_days] = nil
            expect(@checker).not_to be_valid
        end

        it "should validate presence of client_id key" do
            @checker.options[:client_id] = ""
            expect(@checker).not_to be_valid
        end

        it "should validate presence of client_secret key" do
            @checker.options[:client_secret] = ""
            expect(@checker).not_to be_valid
        end

        it "should validate presence of 'to' key" do
            @checker.options[:to] = ""
            expect(@checker).not_to be_valid
        end
    end
end
