# encoding: utf-8

require 'rails_helper'

describe Agents::LiquidOutputAgent do
  let(:agent) do
    _agent = Agents::LiquidOutputAgent.new(:name => 'My Data Output Agent')
    _agent.options = _agent.default_options.merge('secrets' => ['secret1', 'secret2'], 'events_to_show' => 3)
    _agent.options['secrets'] = "a secret"
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::LiquidOutputAgent.async_receive agent.id, [events(:bob_website_agent_event).id]
      expect(agent.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(agent.reload).not_to be_working
    end
  end
end
