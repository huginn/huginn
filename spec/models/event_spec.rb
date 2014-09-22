require 'spec_helper'

describe Event do
  describe ".with_location" do
    it "selects events with location" do
      event = events(:bob_website_agent_event)
      event.lat = 2
      event.lng = 3
      event.save!
      Event.with_location.pluck(:id).should == [event.id]

      event.lat = nil
      event.save!
      Event.with_location.should be_empty
    end
  end

  describe "#location" do
    it "returns a default hash when an event does not have a location" do
      event = events(:bob_website_agent_event)
      event.location.should == Location.new(
        lat: nil,
        lng: nil,
        radius: 0.0,
        speed: nil,
        course: nil)
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
      event.location.should == Location.new(
        lat: 2.0,
        lng: 3.0,
        radius: 0.0,
        speed: 0.5,
        course: 90.0)
    end
  end

  describe "#reemit" do
    it "creates a new event identical to itself" do
      events(:bob_website_agent_event).lat = 2
      events(:bob_website_agent_event).lng = 3
      events(:bob_website_agent_event).created_at = 2.weeks.ago
      lambda {
        events(:bob_website_agent_event).reemit!
      }.should change { Event.count }.by(1)
      Event.last.payload.should == events(:bob_website_agent_event).payload
      Event.last.agent.should == events(:bob_website_agent_event).agent
      Event.last.lat.should == 2
      Event.last.lng.should == 3
      Event.last.created_at.to_i.should be_within(2).of(Time.now.to_i)
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
      Event.find_by_id(half_hour_event.id).should_not be_nil
      Event.find_by_id(one_hour_event.id).should_not be_nil
      Event.find_by_id(two_hour_event.id).should_not be_nil
      Event.find_by_id(three_hour_event.id).should_not be_nil
      Event.find_by_id(non_expiring_event.id).should_not be_nil
      agents(:bob_weather_agent).reload.events_count.should == initial_bob_count
      agents(:jane_weather_agent).reload.events_count.should == initial_jane_count

      current_time = 119.minutes.from_now # move almost 2 hours into the future
      Event.cleanup_expired!
      Event.find_by_id(half_hour_event.id).should be_nil
      Event.find_by_id(one_hour_event.id).should be_nil
      Event.find_by_id(two_hour_event.id).should_not be_nil
      Event.find_by_id(three_hour_event.id).should_not be_nil
      Event.find_by_id(non_expiring_event.id).should_not be_nil
      agents(:bob_weather_agent).reload.events_count.should == initial_bob_count - 1
      agents(:jane_weather_agent).reload.events_count.should == initial_jane_count - 1

      current_time = 2.minutes.from_now # move 2 minutes further into the future
      Event.cleanup_expired!
      Event.find_by_id(two_hour_event.id).should be_nil
      Event.find_by_id(three_hour_event.id).should_not be_nil
      Event.find_by_id(non_expiring_event.id).should_not be_nil
      agents(:bob_weather_agent).reload.events_count.should == initial_bob_count - 1
      agents(:jane_weather_agent).reload.events_count.should == initial_jane_count - 2
    end

    it "doesn't touch Events with no expired_at" do
      event = Event.new
      event.agent = agents(:jane_weather_agent)
      event.expires_at = nil
      event.save!

      current_time = Time.now
      stub(Time).now { current_time }

      Event.cleanup_expired!
      Event.find_by_id(event.id).should_not be_nil
      current_time = 2.days.from_now
      Event.cleanup_expired!
      Event.find_by_id(event.id).should_not be_nil
    end
  end

  describe "after destroy" do
    it "nullifies any dependent AgentLogs" do
      agent_logs(:log_for_jane_website_agent).outbound_event_id.should be_present
      agent_logs(:log_for_bob_website_agent).outbound_event_id.should be_present

      agent_logs(:log_for_bob_website_agent).outbound_event.destroy

      agent_logs(:log_for_jane_website_agent).reload.outbound_event_id.should be_present
      agent_logs(:log_for_bob_website_agent).reload.outbound_event_id.should be_nil
    end
  end

  describe "caches" do
    describe "when an event is created" do
      it "updates a counter cache on agent" do
        lambda {
          agents(:jane_weather_agent).events.create!(:user => users(:jane))
        }.should change { agents(:jane_weather_agent).reload.events_count }.by(1)
      end

      it "updates last_event_at on agent" do
        lambda {
          agents(:jane_weather_agent).events.create!(:user => users(:jane))
        }.should change { agents(:jane_weather_agent).reload.last_event_at }
      end
    end

    describe "when an event is updated" do
      it "does not touch the last_event_at on the agent" do
        event = agents(:jane_weather_agent).events.create!(:user => users(:jane))

        agents(:jane_weather_agent).update_attribute :last_event_at, 2.days.ago

        lambda {
          event.update_attribute :payload, { 'hello' => 'world' }
        }.should_not change { agents(:jane_weather_agent).reload.last_event_at }
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
    @event.to_liquid.class.should be(EventDrop)
  end

  it 'should have attributes of its payload' do
    t = '{{title}}: {{url}}'
    interpolate(t, @event).should eq('some title: http://some.site.example.org/')
  end

  it 'should use created_at from the payload if it exists' do
    created_at = @event.created_at - 86400
    # Avoid timezone issue by using %s
    @event.payload['created_at'] = created_at.strftime("%s")
    @event.save!
    t = '{{created_at | date:"%s" }}'
    interpolate(t, @event).should eq(created_at.strftime("%s"))
  end

  it 'should be iteratable' do
    # to_liquid returns self
    t = "{% for pair in to_liquid %}{{pair | join:':' }}\n{% endfor %}"
    interpolate(t, @event).should eq("title:some title\nurl:http://some.site.example.org/\n")
  end

  it 'should have agent' do
    t = '{{agent.name}}'
    interpolate(t, @event).should eq('SF Weather')
  end

  it 'should have created_at' do
    t = '{{created_at | date:"%FT%T%z" }}'
    interpolate(t, @event).should eq(@event.created_at.strftime("%FT%T%z"))
  end

  it 'should have _location_' do
    t = '{{_location_.lat}},{{_location_.lng}}'
    interpolate(t, @event).should eq("2.0,3.0")
  end
end
