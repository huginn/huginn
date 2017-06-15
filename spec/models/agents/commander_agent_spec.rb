require 'rails_helper'

describe Agents::CommanderAgent do
  let(:valid_params) {
    {
      name: 'Example',
      schedule: 'every_1h',
      options: {
        'action' => 'run',
      },
    }
  }

  let(:agent) {
    described_class.create!(valid_params) { |agent|
      agent.user = users(:bob)
    }
  }

  it_behaves_like AgentControllerConcern

  describe "check" do
    it "should command targets" do
      stub(agent).control!.once { nil }
      agent.check
    end
  end

  describe "receive_events" do
    it "should command targets" do
      stub(agent).control!.once { nil }

      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = {
        'url' => 'http://xkcd.com',
        'link' => 'Random',
      }
      agent.receive([event])
    end
  end
end
