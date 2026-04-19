require 'rails_helper'

describe Agents::JavaScriptAgent do
  before do
    @valid_params = {
      name: "somename",
      options: {
        code: "Agent.check = function() { this.createEvent({ 'message': 'hi' }); };",
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

    it "accepts a credential, but it must exist" do
      expect(@agent).to be_valid
      @agent.options['code'] = 'credential:foo'
      expect(@agent).not_to be_valid
      users(:jane).user_credentials.create! credential_name: "foo", credential_value: "bar"
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
        allow(Time).to receive(:now) { three_days_from_now }
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
        allow(Time).to receive(:now) { two_days_from_now }
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
        }.not_to(change { AgentLog.count })
      }.to change { Event.count }.by(2)
    end

    describe "using credentials as code" do
      before do
        @agent.user.user_credentials.create credential_name: 'code-foo',
                                            credential_value: 'Agent.check = function() { this.log("ran it"); };'
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
    end

    describe "getMemory" do
      it "won't store NaNs" do
        @agent.options['code'] = 'Agent.check = function() { this.memory("foo", NaN); };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq('NaN') # string
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it "it stores an Array" do
        @agent.options['code'] = 'Agent.check = function() {
          var arr = [1,2];
          this.memory("foo", arr);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq([1, 2])
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it "it stores a Hash" do
        @agent.options['code'] = 'Agent.check = function() {
          var obj = {};
          obj["one"] = 1;
          obj["two"] = [1,2];
          this.memory("foo", obj);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq({ "one" => 1, "two" => [1, 2] })
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it "it stores a nested Hash" do
        @agent.options['code'] = 'Agent.check = function() {
          var u = {};
          u["one"] = 1;
          u["two"] = 2;
          var obj = {};
          obj["three"] = 3;
          obj["four"] = u;
          this.memory("foo", obj);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq({ "three" => 3, "four" => { "one" => 1, "two" => 2 } })
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it "it stores null" do
        @agent.options['code'] = 'Agent.check = function() {
          this.memory("foo", "test");
          this.memory("foo", null);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq(nil)
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end

      it "it stores false" do
        @agent.options['code'] = 'Agent.check = function() {
          this.memory("foo", "test");
          this.memory("foo", false);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to eq(false)
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end
    end

    describe "setMemory" do
      it "stores an object" do
        @agent.options['code'] = 'Agent.check = function() {
          var u = {};
          u["one"] = 1;
          u["two"] = 2;
          this.setMemory(u);
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory).to eq({ "one" => 1, "two" => 2 })
        @agent.save!
        expect { @agent.reload.memory }.not_to raise_error
      end
    end

    describe "deleteKey" do
      it "deletes a memory key" do
        @agent.memory = { foo: "baz" }
        @agent.options['code'] = 'Agent.check = function() {
          this.deleteKey("foo");
          };'
        @agent.save!
        @agent.check
        expect(@agent.memory['foo']).to be_nil
        expect { @agent.reload.memory }.not_to raise_error
      end

      it "returns the string value of the deleted key" do
        @agent.memory = { foo: "baz" }
        @agent.options['code'] = 'Agent.check = function() {
          this.createEvent({ message: this.deleteKey("foo")});
          };'
        @agent.save!
        @agent.check
        created_event = @agent.events.last
        expect(created_event.payload).to eq('message' => "baz")
      end

      it "returns the hash value of the deleted key" do
        @agent.memory = { foo: { baz: 'test' }  }
        @agent.options['code'] = 'Agent.check = function() {
          this.createEvent({ message: this.deleteKey("foo")});
          };'
        @agent.save!
        @agent.check
        created_event = @agent.events.last
        expect(created_event.payload).to eq('message' => { 'baz' => 'test' })
      end
    end

    describe "creating events" do
      it "creates events with this.createEvent in the JavaScript environment" do
        @agent.options['code'] =
          'Agent.check = function() { this.createEvent({ message: "This is an event!", stuff: { foo: 5 } }); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to(change { AgentLog.count })
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
        @agent.options['code'] =
          'Agent.check = function() { this.createEvent({ escaped: this.escapeHtml(\'test \"escaping\" <characters>\'), unescaped: this.unescapeHtml(\'test &quot;unescaping&quot; &lt;characters&gt;\')}); };'
        @agent.save!
        expect {
          expect {
            @agent.check
          }.not_to(change { AgentLog.count })
        }.to change { Event.count }.by(1)
        created_event = @agent.events.last
        expect(created_event.payload).to eq({ 'escaped' => 'test &quot;escaping&quot; &lt;characters&gt;',
                                              'unescaped' => 'test "unescaping" <characters>' })
      end
    end

    describe "getting incoming events" do
      it "can access incoming events in the JavaScript enviroment via this.incomingEvents" do
        event = Event.new
        event.agent = agents(:bob_rain_notifier_agent)
        event.payload = { data: "Something you should know about" }
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
          }.not_to(change { AgentLog.count })
        }.to change { Event.count }.by(2)
        created_event = @agent.events.first
        expect(created_event.payload).to eq({ 'message' => "I got an event!",
                                              'event_was' => { 'data' => "Something you should know about" } })
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
          }.not_to(change { AgentLog.count })
        }.not_to(change { Event.count })
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

  describe "URL and URLSearchParams" do
    it "exposes the WHATWG URL class" do
      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var u = new URL("http://example.com/path?a=1");
          this.createEvent({
            href: u.href,
            host: u.host,
            pathname: u.pathname,
            search: u.search,
            a: u.searchParams.get("a")
          });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({
        'href' => 'http://example.com/path?a=1',
        'host' => 'example.com',
        'pathname' => '/path',
        'search' => '?a=1',
        'a' => '1'
      })
    end

    it "resolves relative URLs against a base" do
      @agent.options['code'] = <<~JS
        Agent.check = function() {
          this.createEvent({ url: new URL("/foo", "http://example.com/bar/").toString() });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({ 'url' => 'http://example.com/foo' })
    end

    it "builds query strings with URLSearchParams" do
      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var params = new URLSearchParams();
          params.append("q", "hello world");
          params.append("tag", "a");
          params.append("tag", "b");
          this.createEvent({ query: params.toString() });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({ 'query' => 'q=hello+world&tag=a&tag=b' })
    end
  end

  describe "fetch" do
    it "performs a GET request and exposes the standard response fields" do
      stub_request(:get, "http://example.com/").to_return(
        status: 200,
        body: '{"hello":"world"}',
        headers: { "Content-Type" => "application/json; charset=utf-8" }
      )

      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var res = this.fetch("http://example.com/");
          this.createEvent({
            ok: res.ok,
            status: res.status,
            statusText: res.statusText,
            url: res.url,
            redirected: res.redirected,
            contentType: res.headers.get("Content-Type"),
            unknownHeader: res.headers.get("X-Missing"),
            json: res.json()
          });
        };
      JS
      @agent.save!
      @agent.check

      payload = @agent.events.last.payload
      expect(payload['ok']).to eq(true)
      expect(payload['status']).to eq(200)
      expect(payload['statusText']).to eq("OK")
      expect(payload['url']).to eq("http://example.com/")
      expect(payload['redirected']).to eq(false)
      expect(payload['contentType']).to eq("application/json; charset=utf-8")
      expect(payload['unknownHeader']).to be_nil
      expect(payload['json']).to eq({ 'hello' => 'world' })
    end

    it "sets ok to false for HTTP error statuses without throwing" do
      stub_request(:get, "http://example.com/404").to_return(status: 404, body: "not found")

      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var res = this.fetch("http://example.com/404");
          this.createEvent({ ok: res.ok, status: res.status, body: res.text() });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({ 'ok' => false, 'status' => 404, 'body' => 'not found' })
    end

    it "sends the method, headers, and body" do
      stub_request(:post, "http://example.com/submit")
        .with(body: '{"x":1}', headers: { 'Content-Type' => 'application/json', 'X-Custom' => 'yes' })
        .to_return(status: 201, body: "created")

      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var res = this.fetch("http://example.com/submit", {
            method: "POST",
            headers: { "Content-Type": "application/json", "X-Custom": "yes" },
            body: JSON.stringify({ x: 1 })
          });
          this.createEvent({ status: res.status, body: res.text() });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({ 'status' => 201, 'body' => 'created' })
    end

    it "follows redirects by default and reports the final url" do
      stub_request(:get, "http://example.com/start").to_return(
        status: 302, headers: { "Location" => "http://example.com/end" }
      )
      stub_request(:get, "http://example.com/end").to_return(status: 200, body: "done")

      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var res = this.fetch("http://example.com/start");
          this.createEvent({ url: res.url, redirected: res.redirected, body: res.text() });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({
        'url' => 'http://example.com/end',
        'redirected' => true,
        'body' => 'done'
      })
    end

    it "does not follow redirects when redirect is manual" do
      stub_request(:get, "http://example.com/start").to_return(
        status: 302, headers: { "Location" => "http://example.com/end" }
      )

      @agent.options['code'] = <<~JS
        Agent.check = function() {
          var res = this.fetch("http://example.com/start", { redirect: "manual" });
          this.createEvent({ status: res.status, location: res.headers.get("Location") });
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload).to eq({
        'status' => 302,
        'location' => 'http://example.com/end'
      })
    end

    it "throws a TypeError on connection failures" do
      stub_request(:get, "http://example.com/").to_raise(Faraday::ConnectionFailed.new("boom"))

      @agent.options['code'] = <<~JS
        Agent.check = function() {
          try {
            this.fetch("http://example.com/");
          } catch (e) {
            this.createEvent({ name: e.name, message: e.message });
          }
        };
      JS
      @agent.save!
      @agent.check

      payload = @agent.events.last.payload
      expect(payload['name']).to eq('TypeError')
      expect(payload['message']).to match(/Connection failed/)
    end

    describe "fetchAll" do
      it "performs multiple requests in parallel and preserves order" do
        stub_request(:get, "http://example.com/a").to_return(status: 200, body: "A")
        stub_request(:get, "http://example.com/b").to_return(status: 201, body: "B")
        stub_request(:post, "http://example.com/c").with(body: "payload").to_return(status: 200, body: "C")

        @agent.options['code'] = <<~JS
          Agent.check = function() {
            var results = this.fetchAll([
              "http://example.com/a",
              ["http://example.com/b"],
              ["http://example.com/c", { method: "POST", body: "payload" }]
            ]);
            this.createEvent({
              statuses: results.map(function(r) { return r.status; }),
              bodies: results.map(function(r) { return r.text(); })
            });
          };
        JS
        @agent.save!
        @agent.check

        expect(@agent.events.last.payload).to eq({
          'statuses' => [200, 201, 200],
          'bodies' => ['A', 'B', 'C']
        })
      end

      it "does not throw on HTTP error statuses" do
        stub_request(:get, "http://example.com/ok").to_return(status: 200, body: "ok")
        stub_request(:get, "http://example.com/missing").to_return(status: 404, body: "nope")

        @agent.options['code'] = <<~JS
          Agent.check = function() {
            var results = this.fetchAll(["http://example.com/ok", "http://example.com/missing"]);
            this.createEvent({ oks: results.map(function(r) { return r.ok; }) });
          };
        JS
        @agent.save!
        @agent.check

        expect(@agent.events.last.payload).to eq({ 'oks' => [true, false] })
      end

      it "throws a TypeError when any request fails with a network error" do
        stub_request(:get, "http://example.com/ok").to_return(status: 200, body: "ok")
        stub_request(:get, "http://example.com/dead").to_raise(Faraday::ConnectionFailed.new("boom"))

        @agent.options['code'] = <<~JS
          Agent.check = function() {
            try {
              this.fetchAll(["http://example.com/ok", "http://example.com/dead"]);
            } catch (e) {
              this.createEvent({ name: e.name, message: e.message });
            }
          };
        JS
        @agent.save!
        @agent.check

        payload = @agent.events.last.payload
        expect(payload['name']).to eq('TypeError')
        expect(payload['message']).to match(/Connection failed/)
      end

      it "throws a TypeError when given a non-array" do
        @agent.options['code'] = <<~JS
          Agent.check = function() {
            try {
              this.fetchAll("not an array");
            } catch (e) {
              this.createEvent({ name: e.name });
            }
          };
        JS
        @agent.save!
        @agent.check

        expect(@agent.events.last.payload).to eq({ 'name' => 'TypeError' })
      end

      it "rejects invalid urls before performing any request" do
        @agent.options['code'] = <<~JS
          Agent.check = function() {
            try {
              this.fetchAll(["http://example.com/", "file:///etc/passwd"]);
            } catch (e) {
              this.createEvent({ message: e.message });
            }
          };
        JS
        @agent.save!
        @agent.check

        expect(@agent.events.last.payload['message']).to match(/http and https/)
      end
    end

    it "rejects non-http urls" do
      @agent.options['code'] = <<~JS
        Agent.check = function() {
          try {
            this.fetch("file:///etc/passwd");
          } catch (e) {
            this.createEvent({ message: e.message });
          }
        };
      JS
      @agent.save!
      @agent.check

      expect(@agent.events.last.payload['message']).to match(/http and https/)
    end
  end

  describe "KVS" do
    before do
      Agents::KeyValueStoreAgent.create!(
        name: "kvs1",
        options: {
          key: "{{ key }}",
          value: "{{ value }}",
          variable: "var1",
        },
        memory: {
          x: "Huginn",
        },
        user: users(:jane),
        control_targets: [@agent]
      )

      Agents::KeyValueStoreAgent.create!(
        name: "kvs2",
        options: {
          key: "{{ key }}",
          value: "{{ value }}",
          variable: "var2",
        },
        memory: {
          y: "Muninn",
        },
        user: users(:jane),
        control_targets: [@agent]
      )
    end

    it "can be accessed via Agent.kvs()" do
      @agent.options['code'] = <<~JS
        Agent.check = function() {
          this.createEvent({ message: `I got values from KVS: ${this.kvs.var1["x"]} and ${this.kvs.var2["y"]}.` });
        };
      JS
      @agent.save!

      expect {
        @agent.check
      }.to change { @agent.events.count }.by(1)

      created_event = @agent.events.last
      expect(created_event.payload).to eq("message" => "I got values from KVS: Huginn and Muninn.")
    end
  end
end
