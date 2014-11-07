require 'spec_helper'

describe Agents::GithubEventsAgent do
  let(:valid_options) {
    {
      'expected_update_period_in_days' => 1,
      'org' => 'github'
    }
  }

  let(:agent) do
    Agents::GithubEventsAgent.new(name: "github agent", options: valid_options).tap { |agent|
      agent.user = users(:jane)
    }
  end

  describe "#check" do
    FakeEventClass = Struct.new(:id)

    let(:fake_event1) { FakeEventClass.new(10) }
    let(:fake_event2) { FakeEventClass.new(2) }
    let(:fake_event3) { FakeEventClass.new(5) }
    let(:fake_event4) { FakeEventClass.new(15) }
    let(:events) { [fake_event1, fake_event2] }

    before do
      agent.save!
      stub(agent).github_events { events }
    end

    describe "the first run" do
      it "emits events" do
        expect {
          agent.check
        }.to change { agent.events.count }.by(2)
      end
    end

    describe "subsequent runs" do
      it "only emits events with ids larger than any yet seen" do
        expect {
          agent.check
        }.to change { agent.events.count }.by(2)

        events << fake_event3

        expect {
          agent.check
        }.to change { agent.events.count }.by(0)

        events << fake_event4

        expect {
          agent.check
        }.to change { agent.events.count }.by(1)
      end

      it "resets if the org or user are changed" do
        expect {
          agent.check
        }.to change { agent.events.count }.by(2)

        agent.options['org'] = 'another_org'

        expect {
          agent.check
        }.to change { agent.events.count }.by(2)

        agent.options['org'] = ''
        agent.options['user'] = 'someone'

        expect {
          agent.check
        }.to change { agent.events.count }.by(2)

        expect {
          agent.check
        }.to change { agent.events.count }.by(0)
      end
    end
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end

    it "should validate presence of user or org" do
      agent.options['user'] = ""
      agent.options['org'] = ""
      expect(agent).not_to be_valid
      agent.options['org'] = "something"
      expect(agent).to be_valid
      agent.options['org'] = ""
      agent.options['user'] = "something"
      expect(agent).to be_valid
    end

    it "should validate presence of expected_update_period_in_days" do
      agent.options['expected_update_period_in_days'] = ""
      expect(agent).not_to be_valid
    end
  end
end
