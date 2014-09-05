require 'spec_helper'

describe Event do
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
end
