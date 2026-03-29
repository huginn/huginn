require 'rails_helper'

describe Agents::DropboxFileUrlAgent do
  before(:each) do
    @agent = Agents::DropboxFileUrlAgent.new(
      name: 'dropbox file to url',
      options: {}
    )
    @agent.user = users(:bob)
    @agent.service = services(:generic)
    @agent.save!
  end

  it 'cannot be scheduled' do
    expect(@agent.cannot_be_scheduled?).to eq true
  end

  it 'has agent description' do
    expect(@agent.description).to_not be_nil
  end

  it 'has event description' do
    expect(@agent.event_description).to_not be_nil
  end

  it 'renders the event description when link_type=permanent' do
    @agent.options['link_type'] = 'permanent'
    expect(@agent.event_description).to_not be_nil
  end

  describe "#receive" do
    def event(payload)
      event = Event.new(payload: payload)
      event.agent = agents(:bob_manual_event_agent)
      event
    end

    context 'with temporary urls' do
      let(:first_dropbox_url_payload)  { { 'url' => 'http://dropbox.com/first/path/url' } }
      let(:second_dropbox_url_payload) { { 'url' => 'http://dropbox.com/second/path/url' } }
      let(:third_dropbox_url_payload)  { { 'url' => 'http://dropbox.com/third/path/url' } }

      before(:each) do
        allow(DropboxApiClient).to receive(:new).and_return(
          instance_double(
            DropboxApiClient,
            temporary_url_for: nil
          ).tap do |client|
            allow(client).to receive(:temporary_url_for).with('/first/path').and_return(first_dropbox_url_payload)
            allow(client).to receive(:temporary_url_for).with('/second/path').and_return(second_dropbox_url_payload)
            allow(client).to receive(:temporary_url_for).with('/third/path').and_return(third_dropbox_url_payload)
          end
        )
      end

      context 'with a single path' do
        before(:each) { @event = event(paths: '/first/path') }

        it 'creates one event with the temporary dropbox link' do
          expect { @agent.receive([@event]) }.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq(first_dropbox_url_payload)
        end
      end

      context 'with multiple comma-separated paths' do
        before(:each) { @event = event(paths: '/first/path, /second/path, /third/path') }

        it 'creates one event with the temporary dropbox link for each path' do
          expect { @agent.receive([@event]) }.to change(Event, :count).by(3)
          last_events = Event.last(3)
          expect(last_events[0].payload['url']).to eq('http://dropbox.com/first/path/url')
          expect(last_events[1].payload['url']).to eq('http://dropbox.com/second/path/url')
          expect(last_events[2].payload['url']).to eq('http://dropbox.com/third/path/url')
        end
      end
    end

    context 'with permanent urls' do
      def response_for(url)
        { 'url' => "https://www.dropbox.com/s/#{url}?dl=1" }
      end

      let(:first_dropbox_url_payload)  { response_for('/first/path') }
      let(:second_dropbox_url_payload) { response_for('/second/path') }
      let(:third_dropbox_url_payload)  { response_for('/third/path') }

      before(:each) do
        allow(DropboxApiClient).to receive(:new).and_return(
          instance_double(
            DropboxApiClient,
            permanent_url_for: nil
          ).tap do |client|
            allow(client).to receive(:permanent_url_for).with('/first/path').and_return(first_dropbox_url_payload)
            allow(client).to receive(:permanent_url_for).with('/second/path').and_return(second_dropbox_url_payload)
            allow(client).to receive(:permanent_url_for).with('/third/path').and_return(third_dropbox_url_payload)
          end
        )
        @agent.options['link_type'] = 'permanent'
      end

      it 'creates one event with a single path' do
        expect { @agent.receive([event(paths: '/first/path')]) }.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq(first_dropbox_url_payload)
      end

      it 'creates one event with the permanent dropbox link for each path' do
        event = event(paths: '/first/path, /second/path, /third/path')
        expect { @agent.receive([event]) }.to change(Event, :count).by(3)
        last_events = Event.last(3)
        expect(last_events[0].payload).to eq(first_dropbox_url_payload)
        expect(last_events[1].payload).to eq(second_dropbox_url_payload)
        expect(last_events[2].payload).to eq(third_dropbox_url_payload)
      end
    end
  end
end
