require 'rails_helper'

describe Agents::OpenaiLlmAgent do
  before do
    @valid_options = {
      'api_key' => 'test-api-key',
      'model' => 'gpt-4o-mini',
      'system_message' => 'You are a helpful assistant.',
      'user_message' => '{{ message }}',
      'temperature' => '1',
      'expected_receive_period_in_days' => '1'
    }

    @checker = Agents::OpenaiLlmAgent.new(name: 'OpenAI LLM Agent', options: @valid_options)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = { 'message' => 'What is the weather like in San Francisco?' }
    @event.save!

    @response_body = File.read(Rails.root.join('spec/data_fixtures/openai_chat_completion.json'))

    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(body: @response_body, status: 200, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#validation' do
    it 'is valid with correct options' do
      expect(@checker).to be_valid
    end

    it 'requires api_key' do
      @checker.options['api_key'] = nil
      expect(@checker).not_to be_valid
    end

    it 'requires model' do
      @checker.options['model'] = nil
      expect(@checker).not_to be_valid
    end

    it 'requires user_message' do
      @checker.options['user_message'] = nil
      expect(@checker).not_to be_valid
    end

    it 'validates temperature range' do
      @checker.options['temperature'] = '3'
      expect(@checker).not_to be_valid
    end

    it 'accepts valid temperature' do
      @checker.options['temperature'] = '0.5'
      expect(@checker).to be_valid
    end

    it 'validates max_tokens is positive' do
      @checker.options['max_tokens'] = '0'
      expect(@checker).not_to be_valid
    end
  end

  describe '#receive' do
    it 'creates an event with the LLM response' do
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it 'includes the assistant message in the event payload' do
      @checker.receive([@event])
      event = Event.last
      expect(event.payload['message']).to include('San Francisco')
      expect(event.payload['finish_reason']).to eq('stop')
      expect(event.payload['model']).to eq('gpt-4o-mini')
      expect(event.payload['usage']).to be_a(Hash)
      expect(event.payload['usage']['total_tokens']).to eq(43)
    end

    it 'sends the correct request body' do
      @checker.receive([@event])

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/chat/completions')
        .with { |req|
          body = JSON.parse(req.body)
          body['model'] == 'gpt-4o-mini' &&
            body['messages'].length == 2 &&
            body['messages'][0]['role'] == 'system' &&
            body['messages'][1]['role'] == 'user' &&
            body['messages'][1]['content'] == 'What is the weather like in San Francisco?'
        }
    end

    it 'sends authorization header' do
      @checker.receive([@event])

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/chat/completions')
        .with(headers: { 'Authorization' => 'Bearer test-api-key' })
    end
  end

  describe '#check' do
    before do
      @checker.options['user_message'] = 'Hello, world!'
    end

    it 'creates an event' do
      expect {
        @checker.check
      }.to change { Event.count }.by(1)
    end
  end

  describe 'custom base_url' do
    before do
      @checker.options['base_url'] = 'http://localhost:11434/v1'
      @checker.save!

      stub_request(:post, 'http://localhost:11434/v1/chat/completions')
        .to_return(body: @response_body, status: 200, headers: { 'Content-Type' => 'application/json' })
    end

    it 'uses the custom base URL' do
      @checker.receive([@event])

      expect(WebMock).to have_requested(:post, 'http://localhost:11434/v1/chat/completions')
    end
  end

  describe 'response_format' do
    it 'sends json_object response format when configured' do
      @checker.options['response_format'] = 'json_object'
      @checker.save!

      @checker.receive([@event])

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/chat/completions')
        .with { |req|
          body = JSON.parse(req.body)
          body['response_format'] == { 'type' => 'json_object' }
        }
    end
  end

  describe '#working?' do
    it 'is not working without recent events' do
      expect(@checker).not_to be_working
    end

    it 'is working with recent events' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  describe 'error handling' do
    it 'handles API errors gracefully' do
      error_response = { 'error' => { 'message' => 'Rate limit exceeded' } }.to_json
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(body: error_response, status: 429, headers: { 'Content-Type' => 'application/json' })

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }
    end
  end
end
