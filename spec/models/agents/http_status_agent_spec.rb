require 'rails_helper'

describe 'HttpStatusAgent' do
  before do
    stub_request(:get, 'http://google.com/')
  end

  let(:default_url) { 'http://google.com/' }

  let(:agent_options) do
    {
      url: "{{ url | default: '#{default_url}' }}",
      headers_to_save: '{{ headers_to_save }}',
    }
  end

  let(:agent) do
    Agents::HttpStatusAgent.create!(
      name: SecureRandom.uuid,
      service: services(:generic),
      user: users(:jane),
      options: agent_options
    )
  end

  def created_events
    agent.events.reorder(id: :asc)
  end

  describe "working" do
    it "should be working when the last status is 200" do
      agent.memory['last_status'] = '200'
      expect(agent.working?).to eq(true)
    end

    it "should be working when the last status is 304" do
      agent.memory['last_status'] = '304'
      expect(agent.working?).to eq(true)
    end

    it "should not be working if the status is 0" do
      agent.memory['last_status'] = '0'
      expect(agent.working?).to eq(false)
    end

    it "should not be working if the status is missing" do
      agent.memory['last_status'] = nil
      expect(agent.working?).to eq(false)
    end

    it "should not be working if the status is -1" do
      agent.memory['last_status'] = '-1'
      expect(agent.working?).to eq(false)
    end
  end

  describe "check" do
    let(:url) { "http://#{SecureRandom.uuid}/" }

    let(:default_url) { url }

    let(:agent_options) do
      super().merge(headers_to_save: '')
    end

    it "should check the url" do
      stub = stub_request(:get, url)

      agent.check

      expect(stub).to have_been_requested
    end

  end

  describe "receive" do

    describe "with an event with a successful ping" do

      let(:successful_url) { "http://#{SecureRandom.uuid}/" }
      let(:default_url) { successful_url }

      let(:status_code) { 200 }
      let(:header) { 'X-Some-Header' }
      let(:header_value) { SecureRandom.uuid }

      before do
        stub_request(:get, successful_url).to_return(status: status_code)
      end

      let(:event_with_a_successful_ping) do
        Event.new(payload: { url: successful_url, headers_to_save: "" })
      end

      let(:events) do
        [event_with_a_successful_ping]
      end

      it "should create one event" do
        agent.receive events
        expect(created_events.count).to eq(1)
      end

      it "should note that the successful response succeeded" do
        agent.receive events
        expect(created_events.last[:payload]['response_received']).to eq(true)
      end

      it "should return the status code" do
        agent.receive events
        expect(created_events.last[:payload]['status']).to eq('200')
      end

      it "should remember the status" do
        agent.receive events
        expect(agent.memory['last_status']).to eq('200')
      end

      it "should record the time spent waiting for the reply" do
        agent.receive events
        expect(created_events.last[:payload]['elapsed_time']).not_to be_nil
      end

      it "should not return a header" do
        agent.receive events
        expect(created_events.last[:payload]['headers']).to be_nil
      end

      describe "but the last status code was 200" do
        before do
          agent.memory['last_status'] = '200'
          agent.save!
        end

        describe "and no duplication settings have been set" do
          it "should create one event" do
            agent.receive events
            expect(created_events.count).to eq(1)
          end
        end

        describe "and change settings have been set to true" do
          before do
            agent.options[:changes_only] = 'true'
            agent.save!
          end

          it "should NOT create any events" do
            agent.receive events
            expect(created_events.count).to eq(0)
          end

          describe "but actually, the ping failed" do

            let(:failing_url)    { "http://#{SecureRandom.uuid}/" }
            let(:event_with_a_failing_ping) do
              Event.new(payload: { url: failing_url, headers_to_save: "" })
            end
            let(:events) do
              [event_with_a_successful_ping, event_with_a_failing_ping]
            end

            before do
              stub_request(:get, failing_url).to_return(status: 500)
            end

            it "should create an event" do
              agent.receive events
              expect(created_events.count).to eq(1)
            end
          end
        end

        describe "and change settings have been set to false" do
          before do
            agent.options[:changes_only] = 'false'
            agent.save!
          end

          it "should create one event" do
            agent.receive events
            expect(created_events.count).to eq(1)
          end
        end

      end

      describe "but the status code is not 200" do
        let(:status_code) { 500 }

        it "should return the status code" do
          agent.receive events
          expect(created_events.last[:payload]['status']).to eq('500')
        end

        it "should remember the status" do
          agent.receive events
          expect(agent.memory['last_status']).to eq('500')
        end
      end

      it "should return the original url" do
        agent.receive events
        expect(created_events.last[:payload]['url']).to eq(successful_url)
      end

      it "should return the final url" do
        agent.receive events
        expect(created_events.last[:payload]['final_url']).to eq(successful_url)
      end

      it "should return whether the url redirected" do
        agent.receive events
        expect(created_events.last[:payload]['redirected']).to eq(false)
      end

      describe "but the ping returns a status code of 0" do
        before do
          stub_request(:get, successful_url).to_return(status: 0)
        end

        let(:event_with_a_successful_ping) do
          Event.new(payload: { url: successful_url, headers_to_save: "" })
        end

        it "should create one event" do
          agent.receive events
          expect(created_events.count).to eq(1)
        end

        it "should note that no response was received" do
          agent.receive events
          expect(created_events.last[:payload]['response_received']).to eq(false)
        end

        it "should return the original url" do
          agent.receive events
          expect(created_events.last[:payload]['url']).to eq(successful_url)
        end

        it "should remember no status" do
          agent.memory['last_status'] = '200'
          agent.receive events
          expect(agent.memory['last_status']).to be_nil
        end

      end

      describe "but the ping returns a status code of -1" do
        before do
          stub_request(:get, successful_url).to_return(status: -1)
        end

        let(:event_with_a_successful_ping) do
          Event.new(payload: { url: successful_url, headers_to_save: "" })
        end

        it "should create one event" do
          agent.receive events
          expect(created_events.count).to eq(1)
        end

        it "should note that no response was received" do
          agent.receive events
          expect(created_events.last[:payload]['response_received']).to eq(false)
        end

        it "should return the original url" do
          agent.receive events
          expect(created_events.last[:payload]['url']).to eq(successful_url)
        end

      end

      describe "and with one event with a failing ping" do

        let(:failing_url)    { "http://#{SecureRandom.uuid}/" }
        let(:event_with_a_failing_ping) do
          Event.new(payload: { url: failing_url, headers_to_save: "" })
        end
        let(:events) do
          [event_with_a_successful_ping, event_with_a_failing_ping]
        end

        before do
          stub_request(:get, failing_url).to_raise(RuntimeError) #to_return(status: 500)
        end

        it "should create two events" do
          agent.receive events
          expect(created_events.count).to eq(2)
        end

        it "should note that the failed response failed" do
          agent.receive events
          expect(created_events[1][:payload]['response_received']).to eq(false)
        end

        it "should note that the successful response succeeded" do
          agent.receive events
          expect(created_events[0][:payload]['response_received']).to eq(true)
        end

        it "should return the original url on both events" do
          agent.receive events
          expect(created_events[0][:payload]['url']).to eq(successful_url)
          expect(created_events[1][:payload]['url']).to eq(failing_url)
        end

        it "should record the time spent waiting for the reply" do
          agent.receive events
          expect(created_events[0][:payload]['elapsed_time']).not_to be_nil
          expect(created_events[1][:payload]['elapsed_time']).not_to be_nil
        end

      end

      describe "with a response with a header" do
        before do
          stub_request(:get, successful_url).to_return(
            status: status_code,
            headers: { header => header_value }
          )
        end

        let(:event_with_a_successful_ping) do
          Event.new(payload: { url: successful_url, headers_to_save: header })
        end

        it "should save the header value according to headers_to_save" do
          agent.receive events
          event = created_events.last
          expect(event[:payload]['headers']).not_to be_nil
          expect(event[:payload]['headers'][header]).to eq(header_value)
        end

        context "regarding case-insensitivity" do
          let(:event_with_a_successful_ping) do
            super().tap { |event|
              event.payload[:headers_to_save].swapcase!
            }
          end

          it "should save the header value according to headers_to_save" do
            agent.receive events
            event = created_events.last
            expect(event[:payload]['headers']).not_to be_nil
            expect(event[:payload]['headers'][header.swapcase]).to eq(header_value)
          end
        end
      end

      describe "with existing and non-existing headers specified" do
        let(:nonexistant_header) { SecureRandom.uuid }

        before do
          stub_request(:get, successful_url).to_return(
            status: status_code,
            headers: { header => header_value }
          )
        end

        let(:event_with_a_successful_ping) do
          Event.new(payload: {
                      url: successful_url,
                      headers_to_save: header + "," + nonexistant_header
                    })
        end

        it "should return the existing header's value" do
          agent.receive events
          expect(created_events.last[:payload]['headers'][header]).to eq(header_value)
        end

        it "should return nil for the nonexistant header" do
          agent.receive events
          expect(created_events.last[:payload]['headers'][nonexistant_header]).to be_nil
        end

      end
    end

    describe "validations" do
      before do
        expect(agent).to be_valid
      end

      it "should validate url" do
        agent.options['url'] = ""
        expect(agent).not_to be_valid

        agent.options['url'] = "http://www.google.com"
        expect(agent).to be_valid
      end
    end

  end


end
