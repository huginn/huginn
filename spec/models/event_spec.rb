require 'rails_helper'

describe Event do
  describe ".with_location" do
    it "selects events with location" do
      event = events(:bob_website_agent_event)
      event.lat = 2
      event.lng = 3
      event.save!
      expect(Event.with_location.pluck(:id)).to eq([event.id])

      event.lat = nil
      event.save!
      expect(Event.with_location).to be_empty
    end
  end

  describe "#location" do
    it "returns a default hash when an event does not have a location" do
      event = events(:bob_website_agent_event)
      expect(event.location).to eq(Location.new(
        lat: nil,
        lng: nil,
        radius: 0.0,
        speed: nil,
        course: nil))
    end

    it "returns a hash containing location information" do
      event = events(:bob_website_agent_event)
      event.lat = 2
      event.lng = 3
      event.payload = {
        radius: 300,
        speed: 0.5,
        course: 90.0,
      }
      event.save!
      expect(event.location).to eq(Location.new(
        lat: 2.0,
        lng: 3.0,
        radius: 0.0,
        speed: 0.5,
        course: 90.0))
    end
  end

  describe "#reemit" do
    it "creates a new event identical to itself" do
      events(:bob_website_agent_event).lat = 2
      events(:bob_website_agent_event).lng = 3
      events(:bob_website_agent_event).created_at = 2.weeks.ago
      expect {
        events(:bob_website_agent_event).reemit!
      }.to change { Event.count }.by(1)
      expect(Event.last.payload).to eq(events(:bob_website_agent_event).payload)
      expect(Event.last.agent).to eq(events(:bob_website_agent_event).agent)
      expect(Event.last.lat).to eq(2)
      expect(Event.last.lng).to eq(3)
      expect(Event.last.created_at.to_i).to be_within(2).of(Time.now.to_i)
    end
  end

  describe ".cleanup_expired!" do
    it "removes any Events whose expired_at date is non-null and in the past, updating Agent counter caches" do
      half_hour_event = agents(:jane_weather_agent).create_event :expires_at => 20.minutes.from_now
      one_hour_event = agents(:bob_weather_agent).create_event :expires_at => 1.hours.from_now
      two_hour_event = agents(:jane_weather_agent).create_event :expires_at => 2.hours.from_now
      three_hour_event = agents(:jane_weather_agent).create_event :expires_at => 3.hours.from_now
      non_expiring_event = agents(:bob_weather_agent).create_event({})

      initial_bob_count = agents(:bob_weather_agent).reload.events_count
      initial_jane_count = agents(:jane_weather_agent).reload.events_count

      current_time = Time.now
      stub(Time).now { current_time }

      Event.cleanup_expired!
      expect(Event.find_by_id(half_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(one_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(two_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(three_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(non_expiring_event.id)).not_to be_nil
      expect(agents(:bob_weather_agent).reload.events_count).to eq(initial_bob_count)
      expect(agents(:jane_weather_agent).reload.events_count).to eq(initial_jane_count)

      current_time = 119.minutes.from_now # move almost 2 hours into the future
      Event.cleanup_expired!
      expect(Event.find_by_id(half_hour_event.id)).to be_nil
      expect(Event.find_by_id(one_hour_event.id)).to be_nil
      expect(Event.find_by_id(two_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(three_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(non_expiring_event.id)).not_to be_nil
      expect(agents(:bob_weather_agent).reload.events_count).to eq(initial_bob_count - 1)
      expect(agents(:jane_weather_agent).reload.events_count).to eq(initial_jane_count - 1)

      current_time = 2.minutes.from_now # move 2 minutes further into the future
      Event.cleanup_expired!
      expect(Event.find_by_id(two_hour_event.id)).to be_nil
      expect(Event.find_by_id(three_hour_event.id)).not_to be_nil
      expect(Event.find_by_id(non_expiring_event.id)).not_to be_nil
      expect(agents(:bob_weather_agent).reload.events_count).to eq(initial_bob_count - 1)
      expect(agents(:jane_weather_agent).reload.events_count).to eq(initial_jane_count - 2)
    end

    it "doesn't touch Events with no expired_at" do
      event = Event.new
      event.agent = agents(:jane_weather_agent)
      event.expires_at = nil
      event.save!

      current_time = Time.now
      stub(Time).now { current_time }

      Event.cleanup_expired!
      expect(Event.find_by_id(event.id)).not_to be_nil
      current_time = 2.days.from_now
      Event.cleanup_expired!
      expect(Event.find_by_id(event.id)).not_to be_nil
    end

    it "always keeps the latest Event regardless of its expires_at value only if the database is MySQL" do
      Event.delete_all
      event1 = agents(:jane_weather_agent).create_event expires_at: 1.minute.ago
      event2 = agents(:bob_weather_agent).create_event expires_at: 1.minute.ago

      Event.cleanup_expired!
      case ActiveRecord::Base.connection.adapter_name
      when /\Amysql/i
        expect(Event.all.pluck(:id)).to eq([event2.id])
      else
        expect(Event.all.pluck(:id)).to be_empty
      end
    end
  end

  describe "after destroy" do
    it "nullifies any dependent AgentLogs" do
      expect(agent_logs(:log_for_jane_website_agent).outbound_event_id).to be_present
      expect(agent_logs(:log_for_bob_website_agent).outbound_event_id).to be_present

      agent_logs(:log_for_bob_website_agent).outbound_event.destroy

      expect(agent_logs(:log_for_jane_website_agent).reload.outbound_event_id).to be_present
      expect(agent_logs(:log_for_bob_website_agent).reload.outbound_event_id).to be_nil
    end
  end

  describe "caches" do
    describe "when an event is created" do
      it "updates a counter cache on agent" do
        expect {
          agents(:jane_weather_agent).events.create!(:user => users(:jane))
        }.to change { agents(:jane_weather_agent).reload.events_count }.by(1)
      end

      it "updates last_event_at on agent" do
        expect {
          agents(:jane_weather_agent).events.create!(:user => users(:jane))
        }.to change { agents(:jane_weather_agent).reload.last_event_at }
      end
    end

    describe "when an event is updated" do
      it "does not touch the last_event_at on the agent" do
        event = agents(:jane_weather_agent).events.create!(:user => users(:jane))

        agents(:jane_weather_agent).update_attribute :last_event_at, 2.days.ago

        expect {
          event.update_attribute :payload, { 'hello' => 'world' }
        }.not_to change { agents(:jane_weather_agent).reload.last_event_at }
      end
    end
  end
end

describe EventDrop do
  def interpolate(string, event)
    event.agent.interpolate_string(string, event.to_liquid)
  end

  before do
    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.created_at = Time.now
    @event.payload = {
      'title' => 'some title',
      'url' => 'http://some.site.example.org/',
    }
    @event.lat = 2
    @event.lng = 3
    @event.save!
  end

  it 'should be created via Agent#to_liquid' do
    expect(@event.to_liquid.class).to be(EventDrop)
  end

  it 'should have attributes of its payload' do
    t = '{{title}}: {{url}}'
    expect(interpolate(t, @event)).to eq('some title: http://some.site.example.org/')
  end

  it 'should use created_at from the payload if it exists' do
    created_at = @event.created_at - 86400
    # Avoid timezone issue by using %s
    @event.payload['created_at'] = created_at.strftime("%s")
    @event.save!
    t = '{{created_at | date:"%s" }}'
    expect(interpolate(t, @event)).to eq(created_at.strftime("%s"))
  end

  it 'should be iteratable' do
    # to_liquid returns self
    t = "{% for pair in to_liquid %}{{pair | join:':' }}\n{% endfor %}"
    expect(interpolate(t, @event)).to eq("title:some title\nurl:http://some.site.example.org/\n")
  end

  it 'should have agent' do
    t = '{{agent.name}}'
    expect(interpolate(t, @event)).to eq('SF Weather')
  end

  it 'should have created_at' do
    t = '{{created_at | date:"%FT%T%z" }}'
    expect(interpolate(t, @event)).to eq(@event.created_at.strftime("%FT%T%z"))
  end

  it 'should have _location_' do
    t = '{{_location_.lat}},{{_location_.lng}}'
    expect(interpolate(t, @event)).to eq("2.0,3.0")
  end
end
