require 'rails_helper'

describe 'HttpStatusAgent' do

  let(:agent) do
    Agents::HttpStatusAgent.new(:name => SecureRandom.uuid, :options => valid_params).tap do |a|
      a.service = services(:generic)
      a.user = users(:jane)
      a.options['url'] = 'http://google.com'
      a.save!

      def a.interpolate_with(e, &block)
        @the_event = e
        block.call
      end

      def a.interpolated
        @the_event.payload
      end

      def a.create_event event
        @the_created_events ||= []
        @the_created_events << event
      end

      def a.the_created_events
        @the_created_events || []
      end

      def a.faraday
        @faraday ||= Struct.new(:programmed_responses).new({}).tap do |f|
                       def f.get url
                         programmed_responses[url] || raise('invalid url')
                       end

                       def f.set url, response, time = nil
                         sleep(time/1000) if time
                         programmed_responses[url] = response
                       end
                     end
      end
    end
  end

  let(:valid_params) { {} }

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

    before do

      def agent.interpolated
        @interpolated ||= { :url => SecureRandom.uuid }
      end

      def agent.check_this_url url
        @url = url
      end

      def agent.checked_url
        @url
      end

    end

    it "should check the url" do
      agent.check
      expect(agent.checked_url).to eq(agent.interpolated[:url])
    end

  end

  describe "receive" do

    describe "with an event with a successful ping" do

      let(:successful_url) { SecureRandom.uuid }

      let(:status_code) { 200 }

      let(:event_with_a_successful_ping) do
        agent.faraday.set(successful_url, Struct.new(:status).new(status_code))
        Event.new.tap { |e| e.payload = { url: successful_url } }
      end

      let(:events) do
        [event_with_a_successful_ping]
      end

      it "should create one event" do
        agent.receive events
        expect(agent.the_created_events.count).to eq(1)
      end

      it "should note that the successful response succeeded" do
        agent.receive events
        expect(agent.the_created_events[0][:payload]['response_received']).to eq(true)
      end

      it "should return the status code" do
        agent.receive events
        expect(agent.the_created_events[0][:payload]['status']).to eq('200')
      end

      it "should remember the status" do
        agent.receive events
        expect(agent.memory['last_status']).to eq('200')
      end

      describe "but the status code is not 200" do
        let(:status_code) { 500 }

        it "should return the status code" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['status']).to eq('500')
        end

        it "should remember the status" do
          agent.receive events
          expect(agent.memory['last_status']).to eq('500')
        end
      end

      it "should return the original url" do
        agent.receive events
        expect(agent.the_created_events[0][:payload]['url']).to eq(successful_url)
      end

      describe "but the ping returns a status code of 0" do

        let(:event_with_a_successful_ping) do
          agent.faraday.set(successful_url, Struct.new(:status).new(0))
          Event.new.tap { |e| e.payload = { url: successful_url } }
        end

        it "should create one event" do
          agent.receive events
          expect(agent.the_created_events.count).to eq(1)
        end

        it "should note that no response was received" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['response_received']).to eq(false)
        end

        it "should return the original url" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['url']).to eq(successful_url)
        end

        it "should remember no status" do
          agent.memory['last_status'] = '200'
          agent.receive events
          expect(agent.memory['last_status']).to be_nil
        end

      end

      describe "but the ping returns a status code of -1" do

        let(:event_with_a_successful_ping) do
          agent.faraday.set(successful_url, Struct.new(:status).new(-1))
          Event.new.tap { |e| e.payload = { url: successful_url } }
        end

        it "should create one event" do
          agent.receive events
          expect(agent.the_created_events.count).to eq(1)
        end

        it "should note that no response was received" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['response_received']).to eq(false)
        end

        it "should return the original url" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['url']).to eq(successful_url)
        end

      end

      describe "and with one event with a failing ping" do

        let(:failing_url)    { SecureRandom.uuid }
        let(:event_with_a_failing_ping)    { Event.new.tap { |e| e.payload = { url: failing_url } } }

        let(:events) do
          [event_with_a_successful_ping, event_with_a_failing_ping]
        end

        it "should create two events" do
          agent.receive events
          expect(agent.the_created_events.count).to eq(2)
        end

        it "should note that the failed response failed" do
          agent.receive events
          expect(agent.the_created_events[1][:payload]['response_received']).to eq(false)
        end

        it "should note that the successful response succeeded" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['response_received']).to eq(true)
        end

        it "should return the original url on both events" do
          agent.receive events
          expect(agent.the_created_events[0][:payload]['url']).to eq(successful_url)
          expect(agent.the_created_events[1][:payload]['url']).to eq(failing_url)
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
