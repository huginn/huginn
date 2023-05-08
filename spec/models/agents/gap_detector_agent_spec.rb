require 'rails_helper'

describe Agents::GapDetectorAgent do
  let(:valid_params) {
    {
      'name' => "my gap detector agent",
      'options' => {
        'window_duration_in_days' => "2",
        'message' => "A gap was found!"
      }
    }
  }

  let(:agent) {
    _agent = Agents::GapDetectorAgent.new(valid_params)
    _agent.user = users(:bob)
    _agent.save!
    _agent
  }

  describe 'validation' do
    before do
      expect(agent).to be_valid
    end

    it 'should validate presence of message' do
      agent.options['message'] = nil
      expect(agent).not_to be_valid
    end

    it 'should validate presence of window_duration_in_days' do
      agent.options['window_duration_in_days'] = ""
      expect(agent).not_to be_valid

      agent.options['window_duration_in_days'] = "wrong"
      expect(agent).not_to be_valid

      agent.options['window_duration_in_days'] = "1"
      expect(agent).to be_valid

      agent.options['window_duration_in_days'] = "0.5"
      expect(agent).to be_valid
    end
  end

  describe '#receive' do
    context 'single stream' do
      it 'records the event if it has a created_at newer than the last seen' do
        agent.receive([events(:bob_website_agent_event)])
        expect(agent.memory['newest_event_created_at']).to eq events(:bob_website_agent_event).created_at.to_i

        events(:bob_website_agent_event).created_at = 2.days.ago

        expect {
          agent.receive([events(:bob_website_agent_event)])
        }.to_not change { agent.memory['newest_event_created_at'] }

        events(:bob_website_agent_event).created_at = 2.days.from_now

        expect {
          agent.receive([events(:bob_website_agent_event)])
        }.to change { agent.memory['newest_event_created_at'] }.to(events(:bob_website_agent_event).created_at.to_i)
      end

      it 'ignores the event if value_path is present and the value at the path is blank' do
        agent.options['value_path'] = 'title'
        agent.receive([events(:bob_website_agent_event)])
        expect(agent.memory['newest_event_created_at']).to eq events(:bob_website_agent_event).created_at.to_i

        events(:bob_website_agent_event).created_at = 2.days.from_now
        events(:bob_website_agent_event).payload['title'] = ''

        expect {
          agent.receive([events(:bob_website_agent_event)])
        }.to_not change { agent.memory['newest_event_created_at'] }

        events(:bob_website_agent_event).payload['title'] = 'present!'

        expect {
          agent.receive([events(:bob_website_agent_event)])
        }.to change { agent.memory['newest_event_created_at'] }.to(events(:bob_website_agent_event).created_at.to_i)
      end

      it 'clears any previous alert' do
        agent.memory['alerted_at'] = 2.days.ago.to_i
        agent.receive([events(:bob_website_agent_event)])
        expect(agent.memory).to_not have_key('alerted_at')
      end
    end

    context 'multi stream' do
      it 'records the event for the specific stream' do
        agent.options["stream_path"] = "my_option"
        event = events(:bob_website_agent_event)
        event.payload["my_option"] = "stream1"
        agent.receive([event])
        expect(agent.memory['stream1']['newest_event_created_at']).to eq event.created_at.to_i

        event.created_at = 2.days.ago

        expect {
          agent.receive([events(:bob_website_agent_event)])
        }.to_not change { agent.memory['stream1']['newest_event_created_at'] }

        event.created_at = 2.days.from_now

        expect {
          agent.receive([events(:bob_website_agent_event)])
        }.to change { agent.memory['stream1']['newest_event_created_at'] }.to(event.created_at.to_i)
      end

      it 'clears any previous alert' do
        agent.options["stream_path"] = "my_option"
        event = events(:bob_website_agent_event)
        event.payload["my_option"] = "stream1"
        agent.memory['stream1'] = { 'alerted_at' => 2.days.ago.to_i }
        agent.receive([event])
        expect(agent.memory['stream1']).to_not have_key('alerted_at')
      end
    end
  end

  describe '#check' do
    context 'single stream' do
      it 'alerts once if no data has been received during window_duration_in_days' do
        agent.memory['newest_event_created_at'] = 1.days.ago.to_i

        expect {
          agent.check
        }.to_not change { agent.events.count }

        agent.memory['newest_event_created_at'] = 3.days.ago.to_i

        expect {
          agent.check
        }.to change { agent.events.count }.by(1)

        expect(agent.events.last.payload).to eq ({ 'message' => 'A gap was found!',
                                                   'gap_started_at' => agent.memory['newest_event_created_at'] })

        expect {
          agent.check
        }.not_to change { agent.events.count }
      end
    end

    context 'multisream stream' do
      it 'alerts once for each stream for which no data has been received during window_duration_in_days' do
        agent.options["stream_path"] = "my_option"
        agent.memory['stream1'] = { 'newest_event_created_at' => 1.days.ago.to_i }
        agent.memory['stream2'] = { 'newest_event_created_at' => 1.days.ago.to_i }
        agent.memory['stream3'] = { 'newest_event_created_at' => 1.days.ago.to_i }

        expect {
          agent.check
        }.to_not change { agent.events.count }

        agent.memory['stream1'] = { 'newest_event_created_at' => 3.days.ago.to_i }
        agent.memory['stream3'] = { 'newest_event_created_at' => 3.days.ago.to_i }

        expect {
          agent.check
        }.to change { agent.events.count }.by(2)

        expect {
          agent.check
        }.not_to change { agent.events.count }
      end

      it 'event should contain the failed stream' do
        agent.options["stream_path"] = "my_option"
        agent.memory['stream99'] = { 'newest_event_created_at' => 3.days.ago.to_i }

        expect {
          agent.check
        }.to change { agent.events.count }.by(1)

        expect(agent.events.last.payload).to eq ({ 'message' => 'A gap was found!',
                                                   'gap_started_at' => agent.memory['stream99']['newest_event_created_at'],
                                                   'stream' => 'stream99'
                                                 })
      end
    end
  end
end
