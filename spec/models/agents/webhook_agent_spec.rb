require 'spec_helper'

describe Agents::WebhookAgent do
  let(:agent) do
    _agent = Agents::WebhookAgent.new(:name => 'webhook',
                                      :options => { 'secret' => 'foobar', 'payload_path' => 'payload' })
    _agent.user = users(:bob)
    _agent.save!
    _agent
  end
  let(:payload) { {'some' => 'info'} }

  describe 'receive_web_request' do
    it 'should create event if secret matches' do
      out = nil
      lambda {
        out = agent.receive_web_request({ 'secret' => 'foobar', 'payload' => payload }, "post", "text/html")
      }.should change { Event.count }.by(1)
      out.should eq(['Event Created', 201])
      Event.last.payload.should eq(payload)
    end

    it 'should not create event if secrets dont match' do
      out = nil
      lambda {
        out = agent.receive_web_request({ 'secret' => 'bazbat', 'payload' => payload }, "post", "text/html")
      }.should change { Event.count }.by(0)
      out.should eq(['Not Authorized', 401])
    end

    it "should only accept POSTs" do
      out = nil
      lambda {
        out = agent.receive_web_request({ 'secret' => 'foobar', 'payload' => payload }, "get", "text/html")
      }.should change { Event.count }.by(0)
      out.should eq(['Please use POST requests only', 401])
    end
  end
end
