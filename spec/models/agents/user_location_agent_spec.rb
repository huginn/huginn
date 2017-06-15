require 'rails_helper'

describe Agents::UserLocationAgent do
  before do
    @agent = Agent.build_for_type('Agents::UserLocationAgent', users(:bob),
                                  :name => 'something',
                                  :options => { :secret => 'my_secret',
                                    :max_accuracy => '50',
                                    :min_distance => '50',
                                    :api_key => 'api_key' })
    @agent.save!
  end

  it 'receives an event' do
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }

    expect {
      @agent.receive([event])
    }.to change { @agent.events.count }.by(1)

    expect(@agent.events.last.payload).to eq({ 'longitude' => 123, 'latitude' => 45, 'something' => 'else' })
    expect(@agent.events.last.lat).to eq(45)
    expect(@agent.events.last.lng).to eq(123)
  end

  it 'does not accept a web request that is not POST' do
    %w[get put delete patch].each { |method|
      content, status, content_type = @agent.receive_web_request({ 'secret' => 'my_secret' }, method, 'application/json')
      expect(status).to eq(404)
    }
  end

  it 'requires a valid secret for a web request' do
    content, status, content_type = @agent.receive_web_request({ 'secret' => 'fake' }, 'post', 'application/json')
    expect(status).to eq(401)

    content, status, content_type = @agent.receive_web_request({ 'secret' => 'my_secret' }, 'post', 'application/json')
    expect(status).to eq(200)
  end

  it 'creates an event on a web request' do
    expect {
      @agent.receive_web_request({ 'secret' => 'my_secret', 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }, 'post', 'application/json')
    }.to change { @agent.events.count }.by(1)

    expect(@agent.events.last.payload).to eq({ 'longitude' => 123, 'latitude' => 45, 'something' => 'else' })
    expect(@agent.events.last.lat).to eq(45)
    expect(@agent.events.last.lng).to eq(123)
  end

  it 'does not create event when too inaccurate' do
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'accuracy' => '100', 'something' => 'else' }

    expect {
      @agent.receive([event])
    }.to change { @agent.events.count }.by(0)
  end

  it 'does create event when accurate enough' do
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'accuracy' => '20', 'something' => 'else' }

    expect {
      @agent.receive([event])
    }.to change { @agent.events.count }.by(1)

    expect(@agent.events.last.payload).to eq({ 'longitude' => 123, 'latitude' => 45, 'accuracy' => '20', 'something' => 'else' })
    expect(@agent.events.last.lat).to eq(45)
    expect(@agent.events.last.lng).to eq(123)
  end

  it 'allows a custom accuracy field' do
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    @agent.options['accuracy_field'] = 'estimated_to'
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'estimated_to' => '20', 'something' => 'else' }

    expect {
      @agent.receive([event])
    }.to change { @agent.events.count }.by(1)

    expect(@agent.events.last.payload).to eq({ 'longitude' => 123, 'latitude' => 45, 'estimated_to' => '20', 'something' => 'else' })
    expect(@agent.events.last.lat).to eq(45)
    expect(@agent.events.last.lng).to eq(123)
  end

  it 'does create an event when far enough' do
    @agent.memory["last_location"] = { 'longitude' => 12, 'latitude' => 34, 'something' => 'else' }
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }

    expect {
      @agent.receive([event])
    }.to change { @agent.events.count }.by(1)

    expect(@agent.events.last.payload).to eq({ 'longitude' => 123, 'latitude' => 45, 'something' => 'else' })
    expect(@agent.events.last.lat).to eq(45)
    expect(@agent.events.last.lng).to eq(123)
  end

  it 'does not create an event when too close' do
    @agent.memory["last_location"] = { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.created_at = Time.now
    event.payload = { 'longitude' => 123, 'latitude' => 45, 'something' => 'else' }

    expect {
      @agent.receive([event])
    }.to change { @agent.events.count }.by(0)
  end
end
