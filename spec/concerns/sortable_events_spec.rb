require 'rails_helper'

describe SortableEvents do
  let(:agent_class) {
    Class.new(Agent) do
      include SortableEvents

      default_schedule 'never'

      def self.valid_type?(name)
        true
      end
    end
  }

  def new_agent(events_order = nil)
    options = {}
    options['events_order'] = events_order if events_order
    agent_class.new(name: 'test', options: options) { |agent|
      agent.user = users(:bob)
    }
  end

  describe 'validations' do
    let(:agent_class) {
      Class.new(Agent) do
        include SortableEvents

        default_schedule 'never'

        def self.valid_type?(name)
          true
        end
      end
    }

    def new_agent(events_order = nil)
      options = {}
      options['events_order'] = events_order if events_order
      agent_class.new(name: 'test', options: options) { |agent|
        agent.user = users(:bob)
      }
    end

    it 'should allow events_order to be unspecified, null or an empty array' do
      expect(new_agent()).to be_valid
      expect(new_agent(nil)).to be_valid
      expect(new_agent([])).to be_valid
    end

    it 'should not allow events_order to be a non-array object' do
      agent = new_agent(0)
      expect(agent).not_to be_valid
      expect(agent.errors[:base]).to include(/events_order/)

      agent = new_agent('')
      expect(agent).not_to be_valid
      expect(agent.errors[:base]).to include(/events_order/)

      agent = new_agent({})
      expect(agent).not_to be_valid
      expect(agent.errors[:base]).to include(/events_order/)
    end

    it 'should not allow events_order to be an array containing unexpected objects' do
      agent = new_agent(['{{key}}', 1])
      expect(agent).not_to be_valid
      expect(agent.errors[:base]).to include(/events_order/)

      agent = new_agent(['{{key1}}', ['{{key2}}', 'unknown']])
      expect(agent).not_to be_valid
      expect(agent.errors[:base]).to include(/events_order/)
    end

    it 'should allow events_order to be an array containing strings and valid tuples' do
      agent = new_agent(['{{key1}}', ['{{key2}}'], ['{{key3}}', 'number']])
      expect(agent).to be_valid

      agent = new_agent(['{{key1}}', ['{{key2}}'], ['{{key3}}', 'number'], ['{{key4}}', 'time', true]])
      expect(agent).to be_valid
    end
  end

  describe 'sort_events' do
    let(:payloads) {
      [
        { 'title' => 'TitleA', 'score' => 4,  'updated_on' => '7 Jul 2015' },
        { 'title' => 'TitleB', 'score' => 2,  'updated_on' => '25 Jun 2014' },
        { 'title' => 'TitleD', 'score' => 10, 'updated_on' => '10 Jan 2015' },
        { 'title' => 'TitleC', 'score' => 10, 'updated_on' => '9 Feb 2015' },
      ]
    }

    let(:events) {
      payloads.map { |payload| Event.new(payload: payload) }
    }

    it 'should sort events by a given key' do
      agent = new_agent(['{{title}}'])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleA TitleB TitleC TitleD])

      agent = new_agent([['{{title}}', 'string', true]])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleD TitleC TitleB TitleA])
    end

    it 'should sort events by multiple keys' do
      agent = new_agent([['{{score}}', 'number'], '{{title}}'])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleB TitleA TitleC TitleD])

      agent = new_agent([['{{score}}', 'number'], ['{{title}}', 'string', true]])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleB TitleA TitleD TitleC])
    end

    it 'should sort events by time' do
      agent = new_agent([['{{updated_on}}', 'time']])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleB TitleD TitleC TitleA])
    end

    it 'should sort events stably' do
      agent = new_agent(['<constant>'])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleA TitleB TitleD TitleC])

      agent = new_agent([['<constant>', 'string', true]])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleA TitleB TitleD TitleC])
    end

    it 'should support _index_' do
      agent = new_agent([['{{_index_}}', 'number', true]])
      expect(agent.__send__(:sort_events, events).map { |e| e.payload['title'] }).to eq(%w[TitleC TitleD TitleB TitleA])
    end
  end

  describe 'automatic event sorter' do
    describe 'declaration' do
      let(:passive_agent_class) {
        Class.new(Agent) do
          include SortableEvents

          cannot_create_events!
        end
      }

      let(:active_agent_class) {
        Class.new(Agent) do
          include SortableEvents
        end
      }

      describe 'can_order_created_events!' do
        it 'should refuse to work if called from an Agent that cannot create events' do
          expect {
            passive_agent_class.class_eval do
              can_order_created_events!
            end
          }.to raise_error('Cannot order events for agent that cannot create events')
        end

        it 'should work if called from an Agent that can create events' do
          expect {
            active_agent_class.class_eval do
              can_order_created_events!
            end
          }.not_to raise_error()
        end
      end

      describe 'can_order_created_events?' do
        it 'should return false unless an Agent declares can_order_created_events!' do
          expect(active_agent_class.can_order_created_events?).to eq(false)
          expect(active_agent_class.new.can_order_created_events?).to eq(false)
        end

        it 'should return true if an Agent declares can_order_created_events!' do
          active_agent_class.class_eval do
            can_order_created_events!
          end

          expect(active_agent_class.can_order_created_events?).to eq(true)
          expect(active_agent_class.new.can_order_created_events?).to eq(true)
        end
      end
    end

    describe 'behavior' do
      class Agents::EventOrderableAgent < Agent
        include SortableEvents

        default_schedule 'never'

        can_order_created_events!

        attr_accessor :payloads_to_emit

        def self.valid_type?(name)
          true
        end

        def check
          payloads_to_emit.each do |payload|
            create_event payload: payload
          end
        end

        def receive(events)
          events.each do |event|
            payloads_to_emit.each do |payload|
              create_event payload: payload.merge('title' => payload['title'] + event.payload['title_suffix'])
            end
          end
        end
      end

      let :new_agent do
        options = {}
        options['events_order'] = @events_order
        Agents::EventOrderableAgent.new(name: 'test', options: options) { |agent|
          agent.user = users(:bob)
          agent.payloads_to_emit = payloads
        }
      end

      let(:payloads) {
        [
          { 'title' => 'TitleA', 'score' => 4,  'updated_on' => '7 Jul 2015' },
          { 'title' => 'TitleB', 'score' => 2,  'updated_on' => '25 Jun 2014' },
          { 'title' => 'TitleD', 'score' => 10, 'updated_on' => '10 Jan 2015' },
          { 'title' => 'TitleC', 'score' => 10, 'updated_on' => '9 Feb 2015' },
        ]
      }

      it 'should keep the order of created events unless events_order is specified' do
        [nil, []].each do |events_order|
          @events_order = events_order
          agent = new_agent
          agent.save!
          expect { agent.check }.to change { Event.count }.by(4)
          events = agent.events.last(4).sort_by(&:id)
          expect(events.map(&:payload)).to match_array(payloads)
          expect(events.map { |event| event.payload['title'] }).to eq(%w[TitleA TitleB TitleD TitleC])
        end
      end

      it 'should sort events created in check() in the order specified in events_order' do
        @events_order = [['{{score}}', 'number'], ['{{title}}', 'string', true]]
        agent = new_agent
        agent.save!
        expect { agent.check }.to change { Event.count }.by(4)
        events = agent.events.last(4).sort_by(&:id)
        expect(events.map(&:payload)).to match_array(payloads)
        expect(events.map { |event| event.payload['title'] }).to eq(%w[TitleB TitleA TitleD TitleC])
      end

      it 'should sort events created in receive() in the order specified in events_order' do
        @events_order = [['{{score}}', 'number'], ['{{title}}', 'string', true]]
        agent = new_agent
        agent.save!
        expect {
          agent.receive([Event.new(payload: { 'title_suffix' => ' [new]' }),
                         Event.new(payload: { 'title_suffix' => ' [popular]' })])
        }.to change { Event.count }.by(8)
        events = agent.events.last(8).sort_by(&:id)
        expect(events.map { |event| event.payload['title'] }).to eq([
          'TitleB [new]',     'TitleA [new]',     'TitleD [new]',     'TitleC [new]',
          'TitleB [popular]', 'TitleA [popular]', 'TitleD [popular]', 'TitleC [popular]',
        ])
      end

      describe 'with the include_sort_info option enabled' do
        let :new_agent do
          agent = super()
          agent.options['include_sort_info'] = true
          agent
        end

        it 'should add sort_info to events created in check() when events_order is not specified' do
          agent = new_agent
          agent.save!
          expect { agent.check }.to change { Event.count }.by(4)
          events = agent.events.last(4).sort_by(&:id)
          expect(events.map { |event| event.payload['title'] }).to eq(%w[TitleA TitleB TitleD TitleC])
          expect(events.map { |event| event.payload['sort_info'] }).to eq((1..4).map{ |pos| { 'position' => pos, 'count' => 4 } })
        end

        it 'should add sort_info to events created in check() when events_order is specified' do
          @events_order = [['{{score}}', 'number'], ['{{title}}', 'string', true]]
          agent = new_agent
          agent.save!
          expect { agent.check }.to change { Event.count }.by(4)
          events = agent.events.last(4).sort_by(&:id)
          expect(events.map { |event| event.payload['title'] }).to eq(%w[TitleB TitleA TitleD TitleC])
          expect(events.map { |event| event.payload['sort_info'] }).to eq((1..4).map{ |pos| { 'position' => pos, 'count' => 4 } })
        end

        it 'should add sort_info to events created in receive() when events_order is specified' do
          @events_order = [['{{score}}', 'number'], ['{{title}}', 'string', true]]
          agent = new_agent
          agent.save!
          expect {
            agent.receive([Event.new(payload: { 'title_suffix' => ' [new]' }),
                           Event.new(payload: { 'title_suffix' => ' [popular]' })])
          }.to change { Event.count }.by(8)
          events = agent.events.last(8).sort_by(&:id)
          expect(events.map { |event| event.payload['title'] }).to eq([
            'TitleB [new]',     'TitleA [new]',     'TitleD [new]',     'TitleC [new]',
            'TitleB [popular]', 'TitleA [popular]', 'TitleD [popular]', 'TitleC [popular]',
          ])
          expect(events.map { |event| event.payload['sort_info'] }).to eq((1..4).map{ |pos| { 'position' => pos, 'count' => 4 } } * 2)
        end
      end
    end
  end
end
