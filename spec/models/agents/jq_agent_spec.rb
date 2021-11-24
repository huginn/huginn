require 'rails_helper'

describe Agents::JqAgent do
  def create_event(payload)
    agents(:jane_weather_agent).events.create!(payload: payload)
  end

  let!(:agent) {
    Agents::JqAgent.create!(
      name: 'somename',
      options: {
        filter: '.+{"total": .numbers | add} | del(.numbers)'
      },
      user: users(:jane)
    )
  }

  describe '.should_run?' do
    it 'should be true' do
      expect(Agents::JqAgent).to be_should_run
    end

    context 'when not enabled' do
      before do
        stub.proxy(ENV).[](anything)
        stub(ENV).[]('USE_JQ') { nil }
      end

      it 'should be false' do
        expect(Agents::JqAgent).not_to be_should_run
      end
    end

    context 'when jq command is not available' do
      before do
        stub(Agents::JqAgent).jq_version { nil }
      end

      it 'should be false' do
        expect(Agents::JqAgent).not_to be_should_run
      end
    end
  end

  describe 'validation' do
    before do
      expect(agent).to be_valid
    end

    it 'should validate filter' do
      agent.options.delete(:filter)
      expect(agent).not_to be_valid

      agent.options[:filter] = [1]
      expect(agent).not_to be_valid

      # An empty expression is OK
      agent.options[:filter] = ''
      expect(agent).to be_valid
    end

    it 'should validate variables' do
      agent.options[:variables] = []
      expect(agent).not_to be_valid

      agent.options[:variables] = ''
      expect(agent).not_to be_valid

      agent.options[:variables] = { 'x' => [1, 2, 3] }
      expect(agent).to be_valid
    end
  end

  describe '#receive' do
    let!(:event) { create_event({ name: 'foo', numbers: [1, 2, 3, 4] }) }

    it 'should filter an event and create a single event if the result is an object' do
      expect {
        agent.receive([event])
      }.to change(Event, :count).by(1)

      created_event = agent.events.last

      expect(created_event.payload).to eq({
        'name' => 'foo',
        'total' => 10
      })
    end

    it 'should filter an event and create no event if the result is an empty array' do
      agent.update!(options: { filter: '[]' })

      expect {
        agent.receive([event])
      }.not_to change(Event, :count)
    end

    it 'should filter an event and create no event if the result is a scalar value' do
      agent.update!(options: { filter: '.numbers | add' })

      expect {
        agent.receive([event])
      }.not_to change(Event, :count)
    end

    it 'should filter an event and create no event if the result is an array of scalar values' do
      agent.update!(options: { filter: '.numbers' })

      expect {
        agent.receive([event])
      }.not_to change(Event, :count)
    end

    it 'should filter an event and create multiple events if the result is an array of objects' do
      agent.update!(options: { filter: '. as $original | .numbers[] | $original + { "number": . } | del(.numbers)' })

      expect {
        agent.receive([event])
      }.to change(Event, :count).by(4)

      created_events = agent.events.limit(4)

      expect(created_events.map(&:payload)).to eq([
        {
          'name' => 'foo',
          'number' => 4
        },
        {
          'name' => 'foo',
          'number' => 3
        },
        {
          'name' => 'foo',
          'number' => 2
        },
        {
          'name' => 'foo',
          'number' => 1
        }
      ])
    end

    it 'should reference passed in variables and filter an event' do
      agent.update!(
        options: {
          filter: '.+{ "extra": $somevar }',
          variables: {
            somevar: { foo: ['bar', 'baz'] }
          }
        }
      )

      expect {
        agent.receive([event])
      }.to change(Event, :count).by(1)

      created_event = agent.events.last

      expect(created_event.payload).to eq({
        'name' => 'foo',
        'numbers' => [1, 2, 3, 4],
        'extra' => { 'foo' => ['bar', 'baz'] }
      })
    end
  end
end
