require 'rails_helper'

# Plivo inbound message params
# https://www.plivo.com/docs/sms/api/message#receive-a-message
describe Agents::PlivoReceiveTextAgent do
  before do
    # Skip the real V3 signature check in tests.
    allow(Plivo::Utils).to receive(:valid_signatureV3?) { true }
  end

  let(:payload) {
    {
      "From" => "+12485551111",
      "To" => "+1347555555",
      "Text" => "Hy",
      "Type" => "sms",
      "MessageUUID" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "TotalAmount" => "0",
      "TotalRate" => "0",
      "Units" => "1"
    }
  }

  describe 'receive_plivo_text_message' do
    before do
      @agent = Agents::PlivoReceiveTextAgent.new(
        :name => 'plivoreceive',
        :options => { :auth_id => 'x',
                      :auth_token => 'x',
                      :server_url => 'http://example.com',
                      :expected_receive_period_in_days => 1 }
      )
      @agent.user = users(:bob)
      @agent.save!
    end

    it 'should create event upon receiving request' do
      request = ActionDispatch::Request.new({
        'action_dispatch.request.request_parameters' => payload.merge({ "secret" => "sms-endpoint" }),
        'REQUEST_METHOD' => "POST",
        'HTTP_ACCEPT' => 'application/xml',
        'HTTP_X_PLIVO_SIGNATURE_V3' => "dummy-signature",
        'HTTP_X_PLIVO_SIGNATURE_V3_NONCE' => "dummy-nonce"
      })

      out = nil
      expect {
        out = @agent.receive_web_request(request)
      }.to change { Event.count }.by(1)
      expect(out[1]).to eq(200)
      expect(out[2]).to eq("text/xml")
      expect(out[0]).to include("Response")
      expect(Event.last.payload).to eq(payload)
    end
  end

  describe 'receive_plivo_text_message and send a response' do
    before do
      @agent = Agents::PlivoReceiveTextAgent.new(
        :name => 'plivoreceive',
        :options => { :auth_id => 'x',
                      :auth_token => 'x',
                      :server_url => 'http://example.com',
                      :reply_text => "thanks!",
                      :expected_receive_period_in_days => 1 }
      )
      @agent.user = users(:bob)
      @agent.save!
    end

    it 'should create event and include the reply in the XML response if reply_text is set' do
      request = ActionDispatch::Request.new({
        'action_dispatch.request.request_parameters' => payload.merge({ "secret" => "sms-endpoint" }),
        'REQUEST_METHOD' => "POST",
        'HTTP_ACCEPT' => 'application/xml',
        'HTTP_X_PLIVO_SIGNATURE_V3' => "dummy-signature",
        'HTTP_X_PLIVO_SIGNATURE_V3_NONCE' => "dummy-nonce"
      })
      out = nil
      expect {
        out = @agent.receive_web_request(request)
      }.to change { Event.count }.by(1)
      expect(out[1]).to eq(200)
      expect(out[0]).to include("thanks!")
      expect(out[0]).to include("Message")
      expect(Event.last.payload).to eq(payload)
    end
  end
end
