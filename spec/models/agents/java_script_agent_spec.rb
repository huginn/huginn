require 'spec_helper'

describe Agents::JavaScriptAgent do
  before do
    @valid_params = {
      :name => "somename",
      :options => {
        :code => "Agent.check = function() { this.createEvent({ 'message': 'hi' }); };",
      }
    }

    @agent = Agents::JavaScriptAgent.new(@valid_params)
    @agent.user = users(:jane)
    @agent.save!
  end

  describe "validations" do
    it "requires 'code'" do
      @agent.should be_valid
      @agent.options['code'] = ''
      @agent.should_not be_valid
      @agent.options.delete('code')
      @agent.should_not be_valid
    end

    it "accepts a credential, but it must exist" do
      @agent.should be_valid
      @agent.options['code'] = 'credential:foo'
      @agent.should_not be_valid
      users(:jane).user_credentials.create! :credential_name => "foo", :credential_value => "bar"
      @agent.reload.should be_valid
    end
  end

  describe "#working?" do
    describe "when expected_update_period_in_days is set" do
      it "returns false when more than expected_update_period_in_days have passed since the last event creation" do
        @agent.options['expected_update_period_in_days'] = 1
        @agent.save!
        @agent.should_not be_working
        @agent.check
        @agent.reload.should be_working
        three_days_from_now = 3.days.from_now
        stub(Time).now { three_days_from_now }
        @agent.should_not be_working
      end
    end

    describe "when expected_receive_period_in_days is set" do
      it "returns false when more than expected_receive_period_in_days have passed since the last event was received" do
        @agent.options['expected_receive_period_in_days'] = 1
        @agent.save!
        @agent.should_not be_working
        Agents::JavaScriptAgent.async_receive @agent.id, [events(:bob_website_agent_event).id]
        @agent.reload.should be_working
        two_days_from_now = 2.days.from_now
        stub(Time).now { two_days_from_now }
        @agent.reload.should_not be_working
      end
    end
  end

  describe "executing code" do
    it "works by default" do
      @agent.options = @agent.default_options
      @agent.options['make_event'] = true
      @agent.save!

      lambda {
        lambda {
          @agent.receive([events(:bob_website_agent_event)])
          @agent.check
        }.should_not change { AgentLog.count }
      }.should change { Event.count }.by(2)
    end


    describe "using credentials as code" do
      before do
        @agent.user.user_credentials.create :credential_name => 'code-foo', :credential_value => 'Agent.check = function() { this.log("ran it"); };'
        @agent.options['code'] = 'credential:code-foo'
        @agent.save!
      end

      it "accepts credentials" do
        @agent.check
        AgentLog.last.message.should == "ran it"
      end

      it "logs an error when the credential goes away" do
        @agent.user.user_credentials.delete_all
        @agent.reload.check
        AgentLog.last.message.should == "Unable to find credential"
      end
    end

    describe "error handling" do
      it "should log an error when V8 has issues" do
        @agent.options['code'] = 'syntax error!'
        @agent.save!
        lambda {
          lambda {
            @agent.check
          }.should_not raise_error
        }.should change { AgentLog.count }.by(1)
        AgentLog.last.message.should =~ /Unexpected identifier/
        AgentLog.last.level.should == 4
      end

      it "should log an error when JavaScript throws" do
        @agent.options['code'] = 'Agent.check = function() { throw "oh no"; };'
        @agent.save!
        lambda {
          lambda {
            @agent.check
          }.should_not raise_error
        }.should change { AgentLog.count }.by(1)
        AgentLog.last.message.should =~ /oh no/
        AgentLog.last.level.should == 4
      end

      it "won't store NaNs" do
        @agent.options['code'] = 'Agent.check = function() { this.memory("foo", NaN); };'
        @agent.save!
        @agent.check
        @agent.memory['foo'].should == 'NaN' # string
        @agent.save!
        lambda { @agent.reload.memory }.should_not raise_error
      end
    end

    describe "creating events" do
      it "creates events with this.createEvent in the JavaScript environment" do
        @agent.options['code'] = 'Agent.check = function() { this.createEvent({ message: "This is an event!", stuff: { foo: 5 } }); };'
        @agent.save!
        lambda {
          lambda {
            @agent.check
          }.should_not change { AgentLog.count }
        }.should change { Event.count }.by(1)
        created_event = @agent.events.last
        created_event.payload.should == { 'message' => "This is an event!", 'stuff' => { 'foo' => 5 } }
      end
    end

    describe "logging" do
      it "can output AgentLogs with this.log and this.error in the JavaScript environment" do
        @agent.options['code'] = 'Agent.check = function() { this.log("woah"); this.error("WOAH!"); };'
        @agent.save!
        lambda {
          lambda {
            @agent.check
          }.should_not raise_error
        }.should change { AgentLog.count }.by(2)

        log1, log2 = AgentLog.last(2)

        log1.message.should == "woah"
        log1.level.should == 3
        log2.message.should == "WOAH!"
        log2.level.should == 4
      end
    end

    describe "getting incoming events" do
      it "can access incoming events in the JavaScript enviroment via this.incomingEvents" do
        event = Event.new
        event.agent = agents(:bob_rain_notifier_agent)
        event.payload = { :data => "Something you should know about" }
        event.save!
        event.reload

        @agent.options['code'] = <<-JS
          Agent.receive = function() {
            var events = this.incomingEvents();
            for(var i = 0; i < events.length; i++) {
              this.createEvent({ 'message': 'I got an event!', 'event_was': events[i].payload });
            }
          }
        JS

        @agent.save!
        lambda {
          lambda {
            @agent.receive([events(:bob_website_agent_event), event])
          }.should_not change { AgentLog.count }
        }.should change { Event.count }.by(2)
        created_event = @agent.events.first
        created_event.payload.should == { 'message' => "I got an event!", 'event_was' => { 'data' => "Something you should know about" } }
      end
    end

    describe "getting and setting memory, getting options" do
      it "can access options via this.options and work with memory via this.memory" do
        @agent.options['code'] = <<-JS
          Agent.check = function() {
            if (this.options('make_event')) {
              var callCount = this.memory('callCount') || 0;
              this.memory('callCount', callCount + 1);
            }
          };
        JS

        @agent.save!

        lambda {
          lambda {

            @agent.check
            @agent.memory['callCount'].should_not be_present

            @agent.options['make_event'] = true
            @agent.check
            @agent.memory['callCount'].should == 1

            @agent.check
            @agent.memory['callCount'].should == 2

            @agent.memory['callCount'] = 20
            @agent.check
            @agent.memory['callCount'].should == 21

          }.should_not change { AgentLog.count }
        }.should_not change { Event.count }
      end
    end
  end
end