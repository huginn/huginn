require 'rails_helper'

describe Agents::Elks46SmsAgent do
    before do
        default_options = {
        api_username: 'u6xxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        api_password: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        from: 'Huginn',
        to: ['+46700000000'],
        message: 'This is a message from your friend Huginn.',
        }

        @checker = Agents::Elks46SmsAgent.new name: 'elks46 SMS Tester', options: default_options
        @checker.user = users(:bob)
        @checker.save!
    end

    def event_with_payload(payload)
        event = Event.new
        event.agent = agents(:bob_manual_event_agent)
        event.payload = payload
        event.save!
        event
    end


    def stub_methods
        stub.any_instance_of(Agents::Elks46SmsAgent).send_sms do |params|
            @sent_messages << params
        end
    end

    describe 'validation' do
        before do
            expect(@checker).to be_valid
        end

        it "should validate the presence of api_username" do
            @checker.options[:api_username] = ''
            expect(@checker).not_to be_valid
        end

        it "should validate the presence of api_password" do
            @checker.options[:api_password] = ''
            expect(@checker).not_to be_valid
        end

        it "should validate the presence of from" do
            @checker.options[:from] = ''
            expect(@checker).not_to be_valid
        end

        it "should validate the presence of to" do
            @checker.options[:to] = ''
            expect(@checker).not_to be_valid
        end

        it "should validate the presence of message" do
            @checker.options[:message] = ''
            expect(@checker).not_to be_valid
        end
    end

    describe '#receive' do
        before do
            stub_methods
            @sent_messages = []

            expect(@checker).to be_valid
        end
        it "should receive event" do
            event = event_with_payload from: "Huginn", to: ["+46700000000"],message: "This is a message from your friend Huginn."
            @checker.receive [event]

            expect(@sent_messages).to eq([
                {
                    "api_username": 'u6xxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                    "api_password": 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                    "from": 'Huginn',
                    "to": ["+46700000000"],
                    "message": 'This is a message from your friend Huginn.',
                }.stringify_keys
                ])
            end

    end
end