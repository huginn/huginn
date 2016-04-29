require 'rails_helper'

# Twilio Params
# https://www.twilio.com/docs/api/twiml/sms/twilio_request
# url: https://b924379f.ngrok.io/users/1/web_requests/7/sms-endpoint
# params: {"ToCountry"=>"US", "ToState"=>"NY", "SmsMessageSid"=>"SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "NumMedia"=>"0", "ToCity"=>"NEW YORK", "FromZip"=>"48342", "SmsSid"=>"SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "FromState"=>"MI", "SmsStatus"=>"received", "FromCity"=>"PONTIAC", "Body"=>"Lol", "FromCountry"=>"US", "To"=>"+1347555555", "ToZip"=>"10016", "NumSegments"=>"1", "MessageSid"=>"SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "AccountSid"=>"ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "From"=>"+12485551111", "ApiVersion"=>"2010-04-01"}
# signature: K29NMD9+v5/QLzbdGZW/DRGyxNU=

describe Agents::TwilioReceiveTextAgent do
  before do
    stub.any_instance_of(Twilio::Util::RequestValidator).validate { true }
  end

  let(:payload) { 
    {
      "ToCountry"=>"US",
      "ToState"=>"NY",
      "SmsMessageSid"=>"SMxxxxxxxxxxxxxxxx",
      "NumMedia"=>"0",
      "ToCity"=>"NEW YORK",
      "FromZip"=>"48342",
      "SmsSid"=>"SMxxxxxxxxxxxxxxxx",
      "FromState"=>"MI",
      "SmsStatus"=>"received",
      "FromCity"=>"PONTIAC",
      "Body"=>"Hy ",
      "FromCountry"=>"US",
      "To"=>"+1347555555",
      "ToZip"=>"10016",
      "NumSegments"=>"1",
      "MessageSid"=>"SMxxxxxxxxxxxxxxxx",
      "AccountSid"=>"ACxxxxxxxxxxxxxxxx",
      "From"=>"+12485551111",
      "ApiVersion"=>"2010-04-01"}
  }

  describe 'receive_twilio_text_message' do
    before do
      @agent = Agents::TwilioReceiveTextAgent.new(
                  :name => 'twilioreceive',
                  :options => { :account_sid => 'x',
                               :auth_token => 'x',
                               :server_url => 'http://example.com',
                               :expected_receive_period_in_days => 1
                            }
                  )
      @agent.user = users(:bob)
      @agent.save!
    end

    it 'should create event upon receiving request' do

      request = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => payload.merge({"secret" => "sms-endpoint"}),
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_TWILIO_SIGNATURE' => "HpS7PBa1Agvt4OtO+wZp75IuQa0="
        })

      out = nil
      expect {
        out = @agent.receive_web_request(request)
      }.to change { Event.count }.by(1)
      expect(out).to eq(["<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response></Response>", 201, "text/xml"])
      expect(Event.last.payload).to eq(payload)
    end
  end

  describe 'receive_twilio_text_message and send a response' do
    before do
      @agent = Agents::TwilioReceiveTextAgent.new(
                  :name => 'twilioreceive',
                  :options => { :account_sid => 'x',
                               :auth_token => 'x',
                               :server_url => 'http://example.com',
                               :reply_text => "thanks!",
                               :expected_receive_period_in_days => 1
                            }
                  )
      @agent.user = users(:bob)
      @agent.save!
    end

    it 'should create event and send back TwiML Message if reply_text is set' do
      out = nil
      request = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => payload.merge({"secret" => "sms-endpoint"}),
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_TWILIO_SIGNATURE' => "HpS7PBa1Agvt4OtO+wZp75IuQa0="
        })
      expect {
        out = @agent.receive_web_request(request)
      }.to change { Event.count }.by(1)
      expect(out).to eq(["<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Message>thanks!</Message></Response>", 201, "text/xml"])
      expect(Event.last.payload).to eq(payload)
    end
  end
end
