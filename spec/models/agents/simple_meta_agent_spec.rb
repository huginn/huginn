require 'rails_helper'

describe Agents::SimpleMetaAgent do
  before do
    stub_request(:any, /xkcd/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/xkcd.html")),
                                         status: 200,
                                         headers: {
                                           'X-Status-Message' => 'OK'
                                         })
  end
  let(:agent) do
    _agent = Agents::SimpleMetaAgent.new(name: 'My SimpleMetaAgent')
    _agent.options = _agent.default_options.merge(url: '{{url}}')
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::SimpleMetaAgent.async_receive agent.id, [events(:url_event).id]
      expect(agent.reload).to be_working
      the_future = (agent.options[:expected_receive_period_in_days].to_i + 1).days.from_now
      stub(Time).now { the_future }
      expect(agent.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end
    it "should validate presence of expected_receive_period_in_days" do
      agent.options['expected_receive_period_in_days'] = ""
      expect(agent).not_to be_valid
      agent.options['expected_receive_period_in_days'] = 0
      expect(agent).not_to be_valid
      agent.options['expected_receive_period_in_days'] = -1
      expect(agent).not_to be_valid
    end
    it "should validate presence of url" do
      agent.options[:url] = nil
      expect(agent).not_to be_valid
    end
  end

  describe "#receive" do
    it 'should re-emit event with merged "meta" object' do
      expect {
        agent.receive([events(:url_event)])
      }.to change {Event.count}.by 1
      expect(Event.last.payload['meta']).not_to be nil
    end
    it 'should not emit event if value at url is nil' do
      expect {
        agent.receive([events(:url_less_event)])
      }.to change {Event.count}.by 0
    end
  end

end
