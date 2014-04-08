require 'spec_helper'

describe Agent do
  describe ".run_schedule" do
    before do
      Agents::WeatherAgent.count.should > 0
      Agents::WebsiteAgent.count.should > 0
    end

    it "runs agents with the given schedule" do
      weather_agent_ids = [agents(:bob_weather_agent), agents(:jane_weather_agent)].map(&:id)
      stub(Agents::WeatherAgent).async_check(anything) {|agent_id| weather_agent_ids.delete(agent_id) }
      stub(Agents::WebsiteAgent).async_check(agents(:bob_website_agent).id)
      Agent.run_schedule("midnight")
      weather_agent_ids.should be_empty
    end

    it "groups agents by type" do
      mock(Agents::WeatherAgent).bulk_check("midnight").once
      mock(Agents::WebsiteAgent).bulk_check("midnight").once
      Agent.run_schedule("midnight")
    end

    it "only runs agents with the given schedule" do
      do_not_allow(Agents::WebsiteAgent).async_check
      Agent.run_schedule("blah")
    end

    it "will not run the 'never' schedule" do
      agents(:bob_weather_agent).update_attribute 'schedule', 'never'
      do_not_allow(Agents::WebsiteAgent).async_check
      Agent.run_schedule("never")
    end
  end

  describe "credential" do
    it "should return the value of the credential when credential is present" do
      agents(:bob_weather_agent).credential("aws_secret").should == user_credentials(:bob_aws_secret).credential_value
    end

    it "should return nil when credential is not present" do
      agents(:bob_weather_agent).credential("non_existing_credential").should == nil
    end

    it "should memoize the load" do
      mock.any_instance_of(UserCredential).credential_value.twice { "foo" }
      agents(:bob_weather_agent).credential("aws_secret").should == "foo"
      agents(:bob_weather_agent).credential("aws_secret").should == "foo"
      agents(:bob_weather_agent).reload
      agents(:bob_weather_agent).credential("aws_secret").should == "foo"
      agents(:bob_weather_agent).credential("aws_secret").should == "foo"
    end
  end

  describe "changes to type" do
    it "validates types" do
      source = Agent.new
      source.type = "Agents::WeatherAgent"
      source.should have(0).errors_on(:type)
      source.type = "Agents::WebsiteAgent"
      source.should have(0).errors_on(:type)
      source.type = "Agents::Fake"
      source.should have(1).error_on(:type)
    end

    it "disallows changes to type once a record has been saved" do
      source = agents(:bob_website_agent)
      source.type = "Agents::WeatherAgent"
      source.should have(1).error_on(:type)
    end

    it "should know about available types" do
      Agent.types.should include(Agents::WeatherAgent, Agents::WebsiteAgent)
    end
  end

  describe "with an example Agent" do
    class Agents::SomethingSource < Agent
      default_schedule "2pm"

      def check
        create_event :payload => {}
      end

      def validate_options
        errors.add(:base, "bad is bad") if options[:bad]
      end
    end

    class Agents::CannotBeScheduled < Agent
      cannot_be_scheduled!

      def receive(events)
        events.each do |event|
          create_event :payload => { :events_received => 1 }
        end
      end
    end

    before do
      stub(Agents::SomethingSource).valid_type?("Agents::SomethingSource") { true }
      stub(Agents::CannotBeScheduled).valid_type?("Agents::CannotBeScheduled") { true }
    end

    describe ".default_schedule" do
      it "stores the default on the class" do
        Agents::SomethingSource.default_schedule.should == "2pm"
        Agents::SomethingSource.new.default_schedule.should == "2pm"
      end

      it "sets the default on new instances, allows setting new schedules, and prevents invalid schedules" do
        @checker = Agents::SomethingSource.new(:name => "something")
        @checker.user = users(:bob)
        @checker.schedule.should == "2pm"
        @checker.save!
        @checker.reload.schedule.should == "2pm"
        @checker.update_attribute :schedule, "5pm"
        @checker.reload.schedule.should == "5pm"

        @checker.reload.schedule.should == "5pm"

        @checker.schedule = "this_is_not_real"
        @checker.should have(1).errors_on(:schedule)
      end

      it "should have an empty schedule if it cannot_be_scheduled" do
        @checker = Agents::CannotBeScheduled.new(:name => "something")
        @checker.user = users(:bob)
        @checker.schedule.should be_nil
        @checker.should be_valid
        @checker.schedule = "5pm"
        @checker.save!
        @checker.schedule.should be_nil

        @checker.schedule = "5pm"
        @checker.should have(0).errors_on(:schedule)
        @checker.schedule.should be_nil
      end
    end

    describe "#create_event" do
      before do
        @checker = Agents::SomethingSource.new(:name => "something")
        @checker.user = users(:bob)
        @checker.save!
      end

      it "should use the checker's user" do
        @checker.check
        Event.last.user.should == @checker.user
      end

      it "should log an error if the Agent has been marked with 'cannot_create_events!'" do
        mock(@checker).can_create_events? { false }
        lambda {
          @checker.check
        }.should_not change { Event.count }
        @checker.logs.first.message.should =~ /cannot create events/i
      end
    end

    describe ".async_check" do
      before do
        @checker = Agents::SomethingSource.new(:name => "something")
        @checker.user = users(:bob)
        @checker.save!
      end

      it "records last_check_at and calls check on the given Agent" do
        mock(@checker).check.once {
          @checker.options[:new] = true
        }

        mock(Agent).find(@checker.id) { @checker }

        @checker.last_check_at.should be_nil
        Agents::SomethingSource.async_check(@checker.id)
        @checker.reload.last_check_at.should be_within(2).of(Time.now)
        @checker.reload.options[:new].should be_true # Show that we save options
      end

      it "should log exceptions" do
        mock(@checker).check.once {
          raise "foo"
        }
        mock(Agent).find(@checker.id) { @checker }
        lambda {
          Agents::SomethingSource.async_check(@checker.id)
        }.should raise_error
        log = @checker.logs.first
        log.message.should =~ /Exception/
        log.level.should == 4
      end
    end

    describe ".receive! and .async_receive" do
      before do
        stub_request(:any, /wunderground/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/weather.json")), :status => 200)
        stub.any_instance_of(Agents::WeatherAgent).is_tomorrow?(anything) { true }
      end

      it "should use available events" do
        mock.any_instance_of(Agents::TriggerAgent).receive(anything).once
        Agent.async_check(agents(:bob_weather_agent).id)
        Agent.receive!
      end

      it "should log exceptions" do
        mock.any_instance_of(Agents::TriggerAgent).receive(anything).once {
          raise "foo"
        }
        Agent.async_check(agents(:bob_weather_agent).id)
        lambda {
          Agent.async_receive(agents(:bob_rain_notifier_agent).id, [agents(:bob_weather_agent).events.last.id])
        }.should raise_error
        log = agents(:bob_rain_notifier_agent).logs.first
        log.message.should =~ /Exception/
        log.level.should == 4
      end

      it "should track when events have been seen and not received them again" do
        mock.any_instance_of(Agents::TriggerAgent).receive(anything).once
        Agent.async_check(agents(:bob_weather_agent).id)
        lambda {
          Agent.receive!
        }.should change { agents(:bob_rain_notifier_agent).reload.last_checked_event_id }

        lambda {
          Agent.receive!
        }.should_not change { agents(:bob_rain_notifier_agent).reload.last_checked_event_id }
      end

      it "should not run consumers that have nothing to do" do
        do_not_allow.any_instance_of(Agents::TriggerAgent).receive(anything)
        Agent.receive!
      end

      it "should group events" do
        mock.any_instance_of(Agents::TriggerAgent).receive(anything).twice { |events|
          events.map(&:user).map(&:username).uniq.length.should == 1
        }
        Agent.async_check(agents(:bob_weather_agent).id)
        Agent.async_check(agents(:jane_weather_agent).id)
        Agent.receive!
      end

      it "should ignore events that were created before a particular Link" do
        agent2 = Agents::SomethingSource.new(:name => "something")
        agent2.user = users(:bob)
        agent2.save!
        agent2.check

        mock.any_instance_of(Agents::TriggerAgent).receive(anything).twice
        agents(:bob_weather_agent).check # bob_weather_agent makes an event

        lambda {
          Agent.receive! # event gets propagated
        }.should change { agents(:bob_rain_notifier_agent).reload.last_checked_event_id }

        # This agent creates a few events before we link to it, but after our last check.
        agent2.check
        agent2.check

        # Now we link to it.
        agents(:bob_rain_notifier_agent).sources << agent2
        agent2.links_as_source.first.event_id_at_creation.should == agent2.events.reorder("events.id desc").first.id

        lambda {
          Agent.receive! # but we don't receive those events because they're too old
        }.should_not change { agents(:bob_rain_notifier_agent).reload.last_checked_event_id }

        # Now a new event is created by agent2
        agent2.check

        lambda {
          Agent.receive! # and we receive it
        }.should change { agents(:bob_rain_notifier_agent).reload.last_checked_event_id }
      end
    end

    describe "creating a new agent and then calling .receive!" do
      it "should not backfill events for a newly created agent" do
        Event.delete_all
        sender = Agents::SomethingSource.new(:name => "Sending Agent")
        sender.user = users(:bob)
        sender.save!
        sender.create_event :payload => {}
        sender.create_event :payload => {}
        sender.events.count.should == 2

        receiver = Agents::CannotBeScheduled.new(:name => "Receiving Agent")
        receiver.user = users(:bob)
        receiver.sources << sender
        receiver.save!

        receiver.events.count.should == 0
        Agent.receive!
        receiver.events.count.should == 0
        sender.create_event :payload => {}
        Agent.receive!
        receiver.events.count.should == 1
      end
    end

    describe "creating agents with propagate_immediately = true" do
      it "should schedule subagent events immediately" do
        Event.delete_all
        sender = Agents::SomethingSource.new(:name => "Sending Agent")
        sender.user = users(:bob)
        sender.save!

        receiver = Agents::CannotBeScheduled.new(
           :name => "Receiving Agent",
        )
        receiver.propagate_immediately = true
        receiver.user = users(:bob)
        receiver.sources << sender
        receiver.save!

        sender.create_event :payload => {"message" => "new payload"}
        sender.events.count.should == 1
        receiver.events.count.should == 1
        #should be true without calling Agent.receive!
      end

      it "should only schedule receiving agents that are set to propagate_immediately" do
        Event.delete_all
        sender = Agents::SomethingSource.new(:name => "Sending Agent")
        sender.user = users(:bob)
        sender.save!

        im_receiver = Agents::CannotBeScheduled.new(
           :name => "Immediate Receiving Agent",
        )
        im_receiver.propagate_immediately = true
        im_receiver.user = users(:bob)
        im_receiver.sources << sender

        im_receiver.save!
        slow_receiver = Agents::CannotBeScheduled.new(
           :name => "Slow Receiving Agent",
        )
        slow_receiver.user = users(:bob)
        slow_receiver.sources << sender
        slow_receiver.save!

        sender.create_event :payload => {"message" => "new payload"}
        sender.events.count.should == 1
        im_receiver.events.count.should == 1
        #we should get the quick one
        #but not the slow one
        slow_receiver.events.count.should == 0
        Agent.receive!
        #now we should have one in both
        im_receiver.events.count.should == 1
        slow_receiver.events.count.should == 1
      end
    end

    describe "validations" do
      it "calls validate_options" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.options[:bad] = true
        agent.should have(1).error_on(:base)
        agent.options[:bad] = false
        agent.should have(0).errors_on(:base)
      end

      it "makes options symbol-indifferent before validating" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.options["bad"] = true
        agent.should have(1).error_on(:base)
        agent.options["bad"] = false
        agent.should have(0).errors_on(:base)
      end

      it "makes memory symbol-indifferent before validating" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.memory["bad"] = 2
        agent.save
        agent.memory[:bad].should == 2
      end

      it "should work when assigned a hash or JSON string" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.memory = {}
        agent.memory.should == {}
        agent.memory["foo"].should be_nil

        agent.memory = ""
        agent.memory["foo"].should be_nil
        agent.memory.should == {}

        agent.memory = '{"hi": "there"}'
        agent.memory.should == { "hi" => "there" }

        agent.memory = '{invalid}'
        agent.memory.should == { "hi" => "there" }
        agent.should have(1).errors_on(:memory)

        agent.memory = "{}"
        agent.memory["foo"].should be_nil
        agent.memory.should == {}
        agent.should have(0).errors_on(:memory)

        agent.options = "{}"
        agent.options["foo"].should be_nil
        agent.options.should == {}
        agent.should have(0).errors_on(:options)

        agent.options = '{"hi": 2}'
        agent.options["hi"].should == 2
        agent.should have(0).errors_on(:options)

        agent.options = '{"hi": wut}'
        agent.options["hi"].should == 2
        agent.should have(1).errors_on(:options)
        agent.errors_on(:options).should include("was assigned invalid JSON")

        agent.options = 5
        agent.options["hi"].should == 2
        agent.should have(1).errors_on(:options)
        agent.errors_on(:options).should include("cannot be set to an instance of Fixnum")
      end

      it "should not allow agents owned by other people" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.source_ids = [agents(:bob_weather_agent).id]
        agent.should have(0).errors_on(:sources)
        agent.source_ids = [agents(:jane_weather_agent).id]
        agent.should have(1).errors_on(:sources)
        agent.user = users(:jane)
        agent.should have(0).errors_on(:sources)
      end

      it "validates keep_events_for" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.should be_valid
        agent.keep_events_for = nil
        agent.should have(1).errors_on(:keep_events_for)
        agent.keep_events_for = 1000
        agent.should have(1).errors_on(:keep_events_for)
        agent.keep_events_for = ""
        agent.should have(1).errors_on(:keep_events_for)
        agent.keep_events_for = 5
        agent.should be_valid
        agent.keep_events_for = 0
        agent.should be_valid
        agent.keep_events_for = 365
        agent.should be_valid

        # Rails seems to call to_i on the input. This guards against future changes to that behavior.
        agent.keep_events_for = "drop table;"
        agent.keep_events_for.should == 0
      end
    end

    describe "cleaning up now-expired events" do
      before do
        @agent = Agents::SomethingSource.new(:name => "something")
        @agent.keep_events_for = 5
        @agent.user = users(:bob)
        @agent.save!
        @event = @agent.create_event :payload => { "hello" => "world" }
        @event.expires_at.to_i.should be_within(2).of(5.days.from_now.to_i)
      end

      describe "when keep_events_for has not changed" do
        it "does nothing" do
          mock(@agent).update_event_expirations!.times(0)

          @agent.options[:foo] = "bar1"
          @agent.save!

          @agent.options[:foo] = "bar1"
          @agent.keep_events_for = 5
          @agent.save!
        end
      end

      describe "when keep_events_for is changed" do
        it "updates events' expires_at" do
          lambda {
            @agent.options[:foo] = "bar1"
            @agent.keep_events_for = 3
            @agent.save!
          }.should change { @event.reload.expires_at }
          @event.expires_at.to_i.should be_within(2).of(3.days.from_now.to_i)
        end

        it "updates events relative to their created_at" do
          @event.update_attribute :created_at, 2.days.ago
          @event.reload.created_at.to_i.should be_within(2).of(2.days.ago.to_i)

          lambda {
            @agent.options[:foo] = "bar2"
            @agent.keep_events_for = 3
            @agent.save!
          }.should change { @event.reload.expires_at }
          @event.expires_at.to_i.should be_within(60 * 61).of(1.days.from_now.to_i) # The larger time is to deal with daylight savings
        end

        it "nulls out expires_at when keep_events_for is set to 0" do
          lambda {
            @agent.options[:foo] = "bar"
            @agent.keep_events_for = 0
            @agent.save!
          }.should change { @event.reload.expires_at }.to(nil)
        end
      end
    end
  end

  describe ".trigger_web_request" do
    class Agents::WebRequestReceiver < Agent
      cannot_be_scheduled!
    end

    before do
      stub(Agents::WebRequestReceiver).valid_type?("Agents::WebRequestReceiver") { true }
    end

    context "when .receive_web_request is defined" do
      before do
        @agent = Agents::WebRequestReceiver.new(:name => "something")
        @agent.user = users(:bob)
        @agent.save!

        def @agent.receive_web_request(params, method, format)
          memory['last_request'] = [params, method, format]
          ['Ok!', 200]
        end
      end

      it "calls the .receive_web_request hook, updates last_web_request_at, and saves" do
        @agent.trigger_web_request({ :some_param => "some_value" }, "post", "text/html")
        @agent.reload.memory['last_request'].should == [ { "some_param" => "some_value" }, "post", "text/html" ]
        @agent.last_web_request_at.to_i.should be_within(1).of(Time.now.to_i)
      end
    end

    context "when .receive_webhook is defined" do
      before do
        @agent = Agents::WebRequestReceiver.new(:name => "something")
        @agent.user = users(:bob)
        @agent.save!

        def @agent.receive_webhook(params)
          memory['last_webhook_request'] = params
          ['Ok!', 200]
        end
      end

      it "outputs a deprecation warning and calls .receive_webhook with the params" do
        mock(Rails.logger).warn("DEPRECATED: The .receive_webhook method is deprecated, please switch your Agent to use .receive_web_request.")
        @agent.trigger_web_request({ :some_param => "some_value" }, "post", "text/html")
        @agent.reload.memory['last_webhook_request'].should == { "some_param" => "some_value" }
        @agent.last_web_request_at.to_i.should be_within(1).of(Time.now.to_i)
      end
    end
  end

  describe "recent_error_logs?" do
    it "returns true if last_error_log_at is near last_event_at" do
      agent = Agent.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_true

      agent.last_error_log_at = 11.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_true

      agent.last_error_log_at = 5.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_true

      agent.last_error_log_at = 15.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_false

      agent.last_error_log_at = 2.days.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_false
    end
  end

  describe "scopes" do
    describe "of_type" do
      it "should accept classes" do
        agents = Agent.of_type(Agents::WebsiteAgent)
        agents.should include(agents(:bob_website_agent))
        agents.should include(agents(:jane_website_agent))
        agents.should_not include(agents(:bob_weather_agent))
      end

      it "should accept strings" do
        agents = Agent.of_type("Agents::WebsiteAgent")
        agents.should include(agents(:bob_website_agent))
        agents.should include(agents(:jane_website_agent))
        agents.should_not include(agents(:bob_weather_agent))
      end

      it "should accept instances of an Agent" do
        agents = Agent.of_type(agents(:bob_website_agent))
        agents.should include(agents(:bob_website_agent))
        agents.should include(agents(:jane_website_agent))
        agents.should_not include(agents(:bob_weather_agent))
      end
    end
  end

  describe "#create_event" do
    describe "when the agent has keep_events_for set" do
      before do
        agents(:jane_weather_agent).keep_events_for.should > 0
      end

      it "sets expires_at on created events" do
        event = agents(:jane_weather_agent).create_event :payload => { 'hi' => 'there' }
        event.expires_at.to_i.should be_within(5).of(agents(:jane_weather_agent).keep_events_for.days.from_now.to_i)
      end
    end

    describe "when the agent does not have keep_events_for set" do
      before do
        agents(:jane_website_agent).keep_events_for.should == 0
      end

      it "does not set expires_at on created events" do
        event = agents(:jane_website_agent).create_event :payload => { 'hi' => 'there' }
        event.expires_at.should be_nil
      end
    end
  end
end
