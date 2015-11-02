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

  describe "#receive" do

    let(:first_dropbox_url_payload)  { { 'url' => 'http://dropbox.com/first/path/url' } }
    let(:second_dropbox_url_payload) { { 'url' => 'http://dropbox.com/second/path/url' } }
    let(:third_dropbox_url_payload)  { { 'url' => 'http://dropbox.com/third/path/url' } }

    def create_event(payload)
      event = Event.new(payload: payload)
      event.agent = agents(:bob_manual_event_agent)
      event.save!
      event
    end

    before(:each) do
      stub.proxy(Dropbox::API::Client).new do |api|
        stub(api).find('/first/path')  { stub(Dropbox::API::File.new).direct_url { first_dropbox_url_payload } }
        stub(api).find('/second/path') { stub(Dropbox::API::File.new).direct_url { second_dropbox_url_payload } }
        stub(api).find('/third/path')  { stub(Dropbox::API::File.new).direct_url { third_dropbox_url_payload } }
      end
    end

    context 'with a single path' do

      before(:each) { @event = create_event(paths: '/first/path') }

      it 'creates one event with the temporary dropbox link' do
        expect { @agent.receive([@event]) }.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq(first_dropbox_url_payload)
      end

    end

    context 'with multiple comma-separated paths' do

      before(:each) { @event = create_event(paths: '/first/path, /second/path, /third/path') }

      it 'creates one event with the temporary dropbox link for each path' do
        expect { @agent.receive([@event]) }.to change(Event, :count).by(3)
        last_events = Event.last(3)
        expect(last_events[0].payload).to eq(first_dropbox_url_payload)
        expect(last_events[1].payload).to eq(second_dropbox_url_payload)
        expect(last_events[2].payload).to eq(third_dropbox_url_payload)
      end

    end

  end

end