require 'rails_helper'

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
      expect(@agent).to be_valid
      @agent.options['code'] = ''
      expect(@agent).not_to be_valid
      @agent.options.delete('code')
      expect(@agent).not_to be_valid
    end

    it "checks for a valid 'language', but allows nil" do
      expect(@agent).to be_valid
      @agent.options['language'] = ''
      expect(@agent).to be_valid
      @agent.options.delete('language')
      expect(@agent).to be_valid
      @agent.options['language'] = 'foo'
      expect(@agent).not_to be_valid

      %w[javascript JavaScript coffeescript CoffeeScript].each do |valid_language|
        @agent.options['language'] = valid_language
        expect(@agent).to be_valid
      end
    end

    it "accepts a credential, but it must exist" do
      expect(@agent).to be_valid
      @agent.options['code'] = 'credential:foo'
      expect(@agent).not_to be_valid
      users(:jane).user_credentials.create! :credential_name => "foo", :credential_value => "bar"
      expect(@agent.reload).to be_valid
    end
  end

  describe "#working?" do
    describe "when expected_update_period_in_days is set" do
      it "returns false when more than expected_update_period_in_days have passed since the last event creation" do
        @agent.options['expected_update_period_in_days'] = 1
        @agent.save!
        expect(@agent).not_to be_working
        @agent.check
        expect(@agent.reload).to be_working
        three_days_from_now = 3.days.from_now
        stub(Time).now { three_days_from_now }
        expect(@agent).not_to be_working
      end
    end

    describe "when expected_receive_period_in_days is set" do
      it "returns false when more than expected_receive_period_in_days have passed since the last event was received" do
        @agent.options['expected_receive_period_in_days'] = 1
        @agent.save!
        expect(@agent).not_to be_working
        Agents::JavaScriptAgent.async_receive @agent.id, [events(:bob_website_agent_event).id]
        expect(@agent.reload).to be_working
        two_days_from_now = 2.days.from_now
        stub(Time).now { two_days_from_now }
        expect(@agent.reload).not_to be_working
      end
    end
  end

  describe "executing code" do
    it "works by default" do
      @agent.options = @agent.default_options
      @agent.options['make_event'] = true
      @agent.save!

      expect {
        expect {
          @agent.receive([events(:bob_website_agent_event)])
          @agent.check
        }.not_to change { AgentLog.count }
      }.to change { Event.count }.by(2)
    end

    describe "using credentials as code" do
      before do
        @agent.user.user_credentials.create :credential_name => 'code-foo', :credential_value => 'Agent.check = function() { this.log("ran it"); };'
        @agent.options['code'] = "credential:code-foo\n\n"
        @agent.save!
      end

      it "accepts credentials" do
        @agent.check
        expect(AgentLog.last.message).to eq("ran it")
      end

      it "logs an error when the credential goes away" do
        @agent.user.user_credentials.delete_all
        @agent.reload.check
        expect(AgentLog.last.message).to eq("Unable to find credential")
      end
    end

    describe "error handling" do
      it "should log an error when V8 has issues" do
        @agent.options['code'] = 'syntax error!'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to raise_error
        }.to change { AgentLog.count }.by(1)
        expect(AgentLog.last.message).to match(/Unexpected identifier/)
        expect(AgentLog.last.level).to eq(4)
      end

      it "should log an error when JavaScript throws" do
        @agent.options['code'] = 'Agent.check = function() { throw "oh no"; };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to raise_error
        }.to change { AgentLog.count }.by(1)
        expect(AgentLog.last.message).to match(/oh no/)
        expect(AgentLog.last.level).to eq(4)
      end

      it "won't store NaNs" do
        @agent.options['code'] = 'Agent.check = function() { this.memory("foo", NaN); };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq('NaN') # string
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end
    end

    describe "creating events" do
      it "creates events with this.createEvent in the JavaScript environment" do
        @agent.options['code'] = 'Agent.check = function() { this.createEvent({ message: "This is an event!", stuff: { foo: 5 } }); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to change { AgentLog.count }
        }.to change { Event.count }.by(1)
        created_event = @agent.events.last
        expect(created_event.payload).to eq({ 'message' => "This is an event!", 'stuff' => { 'foo' => 5 } })
      end
    end

    describe "logging" do
      it "can output AgentLogs with this.log and this.error in the JavaScript environment" do
        @agent.options['code'] = 'Agent.check = function() { this.log("woah"); this.error("WOAH!"); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to raise_error
        }.to change { AgentLog.count }.by(2)

        log1, log2 = AgentLog.last(2)

        expect(log1.message).to eq("woah")
        expect(log1.level).to eq(3)
        expect(log2.message).to eq("WOAH!")
        expect(log2.level).to eq(4)
      end
    end

    describe "escaping and unescaping HTML" do
      it "can escape and unescape html with this.escapeHtml and this.unescapeHtml in the javascript environment" do
        @agent.options['code'] = 'Agent.check = function() { this.createEvent({ escaped: this.escapeHtml(\'test \"escaping\" <characters>\'), unescaped: this.unescapeHtml(\'test &quot;unescaping&quot; &lt;characters&gt;\')}); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to change { AgentLog.count }
        }.to change { Event.count}.by(1)
        created_event = @agent.events.last
        expect(created_event.payload).to eq({ 'escaped' => 'test &quot;escaping&quot; &lt;characters&gt;', 'unescaped' => 'test "unescaping" <characters>'})
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
        expect {
          expect {
            @agent.receive([events(:bob_website_agent_event), event])
          }.not_to change { AgentLog.count }
        }.to change { Event.count }.by(2)
        created_event = @agent.events.first
        expect(created_event.payload).to eq({ 'message' => "I got an event!", 'event_was' => { 'data' => "Something you should know about" } })
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

        expect {
          expect {

            @agent.check
            expect(@agent.memory['callCount']).not_to be_present

            @agent.options['make_event'] = true
            @agent.check
            expect(@agent.memory['callCount']).to eq(1)

            @agent.check
            expect(@agent.memory['callCount']).to eq(2)

            @agent.memory['callCount'] = 20
            @agent.check
            expect(@agent.memory['callCount']).to eq(21)

          }.not_to change { AgentLog.count }
        }.not_to change { Event.count }
      end
    end

    describe "using CoffeeScript" do
      it "will accept a 'language' of 'CoffeeScript'" do
        @agent.options['code'] = 'Agent.check = -> this.log("hello from coffeescript")'
        @agent.options['language'] = 'CoffeeScript'
        @agent.save!
        expect {
          @agent.check
        }.not_to raise_error
        expect(AgentLog.last.message).to eq("hello from coffeescript")
      end
    end

    describe "user credentials" do
      it "can access an existing credential" do
        @agent.send(:set_credential, 'test', 'hello')
        @agent.options['code'] = 'Agent.check = function() { this.log(this.credential("test")); };'
        @agent.save!
        @agent.check
        expect(AgentLog.last.message).to eq("hello")
      end

      it "will create a new credential" do
        @agent.options['code'] = 'Agent.check = function() { this.credential("test","1234"); };'
        @agent.save!
        expect {
          @agent.check
        }.to change(UserCredential, :count).by(1)
      end

      it "updates an existing credential" do
        @agent.send(:set_credential, 'test', 1234)
        @agent.options['code'] = 'Agent.check = function() { this.credential("test","12345"); };'
        @agent.save!
        expect {
          @agent.check
        }.to change(UserCredential, :count).by(0)
        expect(@agent.user.user_credentials.last.credential_value).to eq('12345')
      end
    end
  end
end
