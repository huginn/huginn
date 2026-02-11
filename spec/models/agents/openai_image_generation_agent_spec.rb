require 'rails_helper'

describe Agents::OpenaiImageGenerationAgent do
  before do
    @valid_options = {
      'api_key' => 'test-api-key',
      'model' => 'dall-e-3',
      'prompt' => 'A beautiful sunset over the ocean',
      'n' => '1',
      'size' => '1024x1024',
      'quality' => 'standard',
      'style' => 'vivid',
      'response_format' => 'url',
      'expected_receive_period_in_days' => '1'
    }

    @checker = Agents::OpenaiImageGenerationAgent.new(name: 'Image Gen Agent', options: @valid_options)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = { 'prompt' => 'A cat wearing a top hat', 'source' => 'user_request' }
    @event.save!

    @response_body = File.read(Rails.root.join('spec/data_fixtures/openai_image_generation.json'))

    stub_request(:post, 'https://api.openai.com/v1/images/generations')
      .to_return(body: @response_body, status: 200, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#validation' do
    it 'is valid with correct options' do
      expect(@checker).to be_valid
    end

    it 'requires api_key when ENV is not set' do
      @checker.options['api_key'] = nil
      stub_const('ENV', ENV.to_h.except('OPENAI_API_KEY'))
      expect(@checker).not_to be_valid
    end

    it 'accepts missing api_key when ENV is set' do
      @checker.options['api_key'] = nil
      stub_const('ENV', ENV.to_h.merge('OPENAI_API_KEY' => 'env-key'))
      expect(@checker).to be_valid
    end

    it 'requires model' do
      @checker.options['model'] = nil
      expect(@checker).not_to be_valid
    end

    it 'requires prompt' do
      @checker.options['prompt'] = nil
      expect(@checker).not_to be_valid
    end

    it 'validates n is positive' do
      @checker.options['n'] = '0'
      expect(@checker).not_to be_valid
    end

    it 'validates size values' do
      @checker.options['size'] = '999x999'
      expect(@checker).not_to be_valid
    end

    it 'validates response_format values' do
      @checker.options['response_format'] = 'invalid'
      expect(@checker).not_to be_valid
    end

    it 'validates output_mode values' do
      @checker.options['output_mode'] = 'invalid'
      expect(@checker).not_to be_valid
    end

    it 'accepts valid output_mode values' do
      @checker.options['output_mode'] = 'merge'
      expect(@checker).to be_valid
    end
  end

  describe '#check' do
    it 'creates an event with image data' do
      expect {
        @checker.check
      }.to change { Event.count }.by(1)

      event = Event.last
      expect(event.payload['image_url']).to include('blob.core.windows.net')
      expect(event.payload['revised_prompt']).to include('sunset')
      expect(event.payload['prompt']).to eq('A beautiful sunset over the ocean')
      expect(event.payload['model']).to eq('dall-e-3')
      expect(event.payload['index']).to eq(0)
    end
  end

  describe '#receive' do
    it 'creates an event with image data from incoming event' do
      @checker.options['prompt'] = '{{ prompt }}'
      @checker.save!

      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it 'sends the correct prompt from the event' do
      @checker.options['prompt'] = '{{ prompt }}'
      @checker.save!

      @checker.receive([@event])

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with { |req|
          body = JSON.parse(req.body)
          body['prompt'] == 'A cat wearing a top hat'
        }
    end

    it 'sends authorization header' do
      @checker.receive([@event])

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(headers: { 'Authorization' => 'Bearer test-api-key' })
    end
  end

  describe 'output_mode merge' do
    before do
      @checker.options['output_mode'] = 'merge'
      @checker.options['prompt'] = '{{ prompt }}'
      @checker.save!
    end

    it 'merges original event payload into the emitted event' do
      @checker.receive([@event])

      event = Event.last
      # Original payload field preserved
      expect(event.payload['source']).to eq('user_request')
      # Image generation fields present
      expect(event.payload['image_url']).to include('blob.core.windows.net')
      expect(event.payload['model']).to eq('dall-e-3')
    end

    it 'does not merge when called via check (no incoming event)' do
      @checker.check

      event = Event.last
      expect(event.payload).not_to have_key('source')
      expect(event.payload['image_url']).to include('blob.core.windows.net')
    end
  end

  describe 'b64_json response format' do
    before do
      b64_response = {
        'created' => 1677858242,
        'data' => [
          {
            'b64_json' => Base64.strict_encode64('fake-image-data'),
            'revised_prompt' => 'A beautiful sunset'
          }
        ]
      }.to_json

      stub_request(:post, 'https://api.openai.com/v1/images/generations')
        .to_return(body: b64_response, status: 200, headers: { 'Content-Type' => 'application/json' })

      @checker.options['response_format'] = 'b64_json'
      @checker.save!
    end

    it 'includes base64 image data in the event' do
      @checker.check
      event = Event.last
      expect(event.payload['image_base64']).to be_present
      expect(event.payload['image_url']).to be_nil
    end
  end

  describe 'multiple images' do
    before do
      multi_response = {
        'created' => 1677858242,
        'data' => [
          { 'url' => 'https://example.com/image1.png', 'revised_prompt' => 'prompt 1' },
          { 'url' => 'https://example.com/image2.png', 'revised_prompt' => 'prompt 2' }
        ]
      }.to_json

      stub_request(:post, 'https://api.openai.com/v1/images/generations')
        .to_return(body: multi_response, status: 200, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates one event per image' do
      expect {
        @checker.check
      }.to change { Event.count }.by(2)
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
      error_response = { 'error' => { 'message' => 'Invalid prompt' } }.to_json
      stub_request(:post, 'https://api.openai.com/v1/images/generations')
        .to_return(body: error_response, status: 400, headers: { 'Content-Type' => 'application/json' })

      expect {
        @checker.check
      }.not_to change { Event.count }
    end
  end
end
