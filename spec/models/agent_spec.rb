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
        Agent.receive!
        Agent.receive!
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

    describe "validations" do
      it "calls validate_options" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.options[:bad] = true
        agent.should have(1).error_on(:base)
        agent.options[:bad] = false
        agent.should have(0).errors_on(:base)
      end

      it "symbolizes options before validating" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.options["bad"] = true
        agent.should have(1).error_on(:base)
        agent.options["bad"] = false
        agent.should have(0).errors_on(:base)
      end

      it "symbolizes memory before validating" do
        agent = Agents::SomethingSource.new(:name => "something")
        agent.user = users(:bob)
        agent.memory["bad"] = :hello
        agent.save
        agent.memory[:bad].should == :hello
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
end