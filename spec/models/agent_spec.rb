require 'spec_helper'

describe Agent do
  it_behaves_like WorkingHelpers

  describe ".bulk_check" do
    before do
      @weather_agent_count = Agents::WeatherAgent.where(:schedule => "midnight", :disabled => false).count
    end

    it "should run all Agents with the given schedule" do
      mock(Agents::WeatherAgent).async_check(anything).times(@weather_agent_count)
      Agents::WeatherAgent.bulk_check("midnight")
    end

    it "should skip disabled Agents" do
      agents(:bob_weather_agent).update_attribute :disabled, true
      mock(Agents::WeatherAgent).async_check(anything).times(@weather_agent_count - 1)
      Agents::WeatherAgent.bulk_check("midnight")
    end
  end

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

    describe Agents::SomethingSource do
      let(:new_instance) do
        agent = Agents::SomethingSource.new(:name => "some agent")
        agent.user = users(:bob)
        agent
      end

      it_behaves_like LiquidInterpolatable
      it_behaves_like HasGuid
    end

    describe ".short_type" do
      it "returns a short name without 'Agents::'" do
        Agents::SomethingSource.new.short_type.should == "SomethingSource"
        Agents::CannotBeScheduled.new.short_type.should == "CannotBeScheduled"
      end
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
        @checker.reload.options[:new].should be_truthy # Show that we save options
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

      it "should not run disabled Agents" do
        mock(Agent).find(agents(:bob_weather_agent).id) { agents(:bob_weather_agent) }
        do_not_allow(agents(:bob_weather_agent)).check
        agents(:bob_weather_agent).update_attribute :disabled, true
        Agent.async_check(agents(:bob_weather_agent).id)
      end
    end

    describe ".receive!" do
      before do
        stub_request(:any, /wunderground/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/weather.json")), :status => 200)
        stub.any_instance_of(Agents::WeatherAgent).is_tomorrow?(anything) { true }
      end

      it "should use available events" do
        Agent.async_check(agents(:bob_weather_agent).id)
        mock(Agent).async_receive(agents(:bob_rain_notifier_agent).id, anything).times(1)
        Agent.receive!
      end

      it "should not propogate to disabled Agents" do
        Agent.async_check(agents(:bob_weather_agent).id)
        agents(:bob_rain_notifier_agent).update_attribute :disabled, true
        mock(Agent).async_receive(agents(:bob_rain_notifier_agent).id, anything).times(0)
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

    describe ".async_receive" do
      it "should not run disabled Agents" do
        mock(Agent).find(agents(:bob_rain_notifier_agent).id) { agents(:bob_rain_notifier_agent) }
        do_not_allow(agents(:bob_rain_notifier_agent)).receive
        agents(:bob_rain_notifier_agent).update_attribute :disabled, true
        Agent.async_receive(agents(:bob_rain_notifier_agent).id, [1, 2, 3])
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

      it "should not allow source agents owned by other people" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.source_ids = [agents(:bob_weather_agent).id]
        agent.should have(0).errors_on(:sources)
        agent.source_ids = [agents(:jane_weather_agent).id]
        agent.should have(1).errors_on(:sources)
        agent.user = users(:jane)
        agent.should have(0).errors_on(:sources)
      end

      it "should not allow controller agents owned by other people" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.controller_ids = [agents(:bob_weather_agent).id]
        agent.should have(0).errors_on(:controllers)
        agent.controller_ids = [agents(:jane_weather_agent).id]
        agent.should have(1).errors_on(:controllers)
        agent.user = users(:jane)
        agent.should have(0).errors_on(:controllers)
      end

      it "should not allow control target agents owned by other people" do
        agent = Agents::CannotBeScheduled.new(:name => "something")
        agent.user = users(:bob)
        agent.control_target_ids = [agents(:bob_weather_agent).id]
        agent.should have(0).errors_on(:control_targets)
        agent.control_target_ids = [agents(:jane_weather_agent).id]
        agent.should have(1).errors_on(:control_targets)
        agent.user = users(:jane)
        agent.should have(0).errors_on(:control_targets)
      end

      it "should not allow scenarios owned by other people" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)

        agent.scenario_ids = [scenarios(:bob_weather).id]
        agent.should have(0).errors_on(:scenarios)

        agent.scenario_ids = [scenarios(:bob_weather).id, scenarios(:jane_weather).id]
        agent.should have(1).errors_on(:scenarios)

        agent.scenario_ids = [scenarios(:jane_weather).id]
        agent.should have(1).errors_on(:scenarios)

        agent.user = users(:jane)
        agent.should have(0).errors_on(:scenarios)
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

    describe "Agent.build_clone" do
      before do
        Event.delete_all
        @sender = Agents::SomethingSource.new(
          name: 'Agent (2)',
          options: { foo: 'bar2' },
          schedule: '5pm')
        @sender.user = users(:bob)
        @sender.save!
        @sender.create_event :payload => {}
        @sender.create_event :payload => {}
        @sender.events.count.should == 2

        @receiver = Agents::CannotBeScheduled.new(
          name: 'Agent',
          options: { foo: 'bar3' },
          keep_events_for: 3,
          propagate_immediately: true)
        @receiver.user = users(:bob)
        @receiver.sources << @sender
        @receiver.memory[:test] = 1
        @receiver.save!
      end

      it "should create a clone of a given agent for editing" do
        sender_clone = users(:bob).agents.build_clone(@sender)

        sender_clone.attributes.should == Agent.new.attributes.
          update(@sender.slice(:user_id, :type,
            :options, :schedule, :keep_events_for, :propagate_immediately)).
          update('name' => 'Agent (2) (2)', 'options' => { 'foo' => 'bar2' })

        sender_clone.source_ids.should == []

        receiver_clone = users(:bob).agents.build_clone(@receiver)

        receiver_clone.attributes.should == Agent.new.attributes.
          update(@receiver.slice(:user_id, :type,
            :options, :schedule, :keep_events_for, :propagate_immediately)).
          update('name' => 'Agent (3)', 'options' => { 'foo' => 'bar3' })

        receiver_clone.source_ids.should == [@sender.id]
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

  describe '.last_checked_event_id' do
    it "should be updated by setting drop_pending_events to true" do
      agent = agents(:bob_rain_notifier_agent)
      agent.last_checked_event_id = nil
      agent.save!
      agent.update!(drop_pending_events: true)
      agent.reload.last_checked_event_id.should == Event.maximum(:id)
    end

    it "should not affect a virtual attribute drop_pending_events" do
      agent = agents(:bob_rain_notifier_agent)
      agent.update!(drop_pending_events: true)
      agent.reload.drop_pending_events.should == false
    end
  end

  describe ".drop_pending_events" do
    before do
      stub_request(:any, /wunderground/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/weather.json")), status: 200)
      stub.any_instance_of(Agents::WeatherAgent).is_tomorrow?(anything) { true }
    end

    it "should drop pending events while the agent was disabled when set to true" do
      agent1 = agents(:bob_weather_agent)
      agent2 = agents(:bob_rain_notifier_agent)

      -> {
        -> {
          Agent.async_check(agent1.id)
          Agent.receive!
        }.should change { agent1.events.count }.by(1)
      }.should change { agent2.events.count }.by(1)

      agent2.disabled = true
      agent2.save!

      -> {
        -> {
          Agent.async_check(agent1.id)
          Agent.receive!
        }.should change { agent1.events.count }.by(1)
      }.should_not change { agent2.events.count }

      agent2.disabled = false
      agent2.drop_pending_events = true
      agent2.save!

      -> {
        Agent.receive!
      }.should_not change { agent2.events.count }
    end
  end
end

describe AgentDrop do
  def interpolate(string, agent)
    agent.interpolate_string(string, "agent" => agent)
  end

  before do
    @wsa1 = Agents::WebsiteAgent.new(
      name: 'XKCD',
      options: {
        expected_update_period_in_days: 2,
        type: 'html',
        url: 'http://xkcd.com/',
        mode: 'on_change',
        extract: {
          url: { css: '#comic img', value: '@src' },
          title: { css: '#comic img', value: '@alt' },
        },
      },
      schedule: 'every_1h',
      keep_events_for: 2)
    @wsa1.user = users(:bob)
    @wsa1.save!

    @wsa2 = Agents::WebsiteAgent.new(
      name: 'Dilbert',
      options: {
        expected_update_period_in_days: 2,
        type: 'html',
        url: 'http://dilbert.com/',
        mode: 'on_change',
        extract: {
          url: { css: '[id^=strip_enlarged_] img', value: '@src' },
          title: { css: '.STR_DateStrip', value: './/text()' },
        },
      },
      schedule: 'every_12h',
      keep_events_for: 2)
    @wsa2.user = users(:bob)
    @wsa2.save!

    @efa = Agents::EventFormattingAgent.new(
      name: 'Formatter',
      options: {
        instructions: {
          message: '{{agent.name}}: {{title}} {{url}}',
          agent: '{{agent.type}}',
        },
        mode: 'clean',
        matchers: [],
        skip_created_at: 'false',
      },
      keep_events_for: 2,
      propagate_immediately: true)
    @efa.user = users(:bob)
    @efa.sources << @wsa1 << @wsa2
    @efa.memory[:test] = 1
    @efa.save!
  end

  it 'should be created via Agent#to_liquid' do
    @wsa1.to_liquid.class.should be(AgentDrop)
    @wsa2.to_liquid.class.should be(AgentDrop)
    @efa.to_liquid.class.should be(AgentDrop)
  end

  it 'should have .type and .name' do
    t = '{{agent.type}}: {{agent.name}}'
    interpolate(t, @wsa1).should eq('WebsiteAgent: XKCD')
    interpolate(t, @wsa2).should eq('WebsiteAgent: Dilbert')
    interpolate(t, @efa).should eq('EventFormattingAgent: Formatter')
  end

  it 'should have .options' do
    t = '{{agent.options.url}}'
    interpolate(t, @wsa1).should eq('http://xkcd.com/')
    interpolate(t, @wsa2).should eq('http://dilbert.com/')
    interpolate('{{agent.options.instructions.message}}',
                @efa).should eq('{{agent.name}}: {{title}} {{url}}')
  end

  it 'should have .sources' do
    t = '{{agent.sources.size}}: {{agent.sources | map:"name" | join:", "}}'
    interpolate(t, @wsa1).should eq('0: ')
    interpolate(t, @wsa2).should eq('0: ')
    interpolate(t, @efa).should eq('2: XKCD, Dilbert')
  end

  it 'should have .receivers' do
    t = '{{agent.receivers.size}}: {{agent.receivers | map:"name" | join:", "}}'
    interpolate(t, @wsa1).should eq('1: Formatter')
    interpolate(t, @wsa2).should eq('1: Formatter')
    interpolate(t, @efa).should eq('0: ')
  end
end
