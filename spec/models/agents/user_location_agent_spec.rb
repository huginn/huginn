require 'spec_helper'

describe Agents::UserLocationAgent do
  before do
    @agent = Agent.build_for_type('Agents::UserLocationAgent', users(:bob), :name => 'something', :options => { :secret => 'my_secret' })
    @agent.save!
  end

  it 'receives an event' do
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }

    lambda {
      @agent.receive([event])
    }.should change { @agent.events.count }.by(1)

    @agent.events.last.payload.should == { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }
    @agent.events.last.lat.should == 45
    @agent.events.last.lng.should == 123
  end

  it 'does not accept a web request that is not POST' do
    %w[get put delete patch].each { |method|
      content, status, content_type = @agent.receive_web_request({ 'secret' => 'my_secret' }, method, 'application/json')
      status.should == 404
    }
  end

  it 'requires a valid secret for a web request' do
    content, status, content_type = @agent.receive_web_request({ 'secret' => 'fake' }, 'post', 'application/json')
    status.should == 401

    content, status, content_type = @agent.receive_web_request({ 'secret' => 'my_secret' }, 'post', 'application/json')
    status.should == 200
  end

  it 'creates an event on a web request' do
    lambda {
      @agent.receive_web_request({ 'secret' => 'my_secret', 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }, 'post', 'application/json')
    }.should change { @agent.events.count }.by(1)

    @agent.events.last.payload.should == { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }
    @agent.events.last.lat.should == 45
    @agent.events.last.lng.should == 123
  end
end
