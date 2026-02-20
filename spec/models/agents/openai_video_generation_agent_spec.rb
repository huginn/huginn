require 'rails_helper'

describe Agents::OpenaiVideoGenerationAgent do
  before do
    @valid_submit_options = {
      'api_key' => 'test-api-key',
      'model' => 'sora',
      'mode' => 'submit',
      'prompt' => 'A cat playing piano in a jazz club',
      'size' => '1920x1080',
      'n' => '1',
      'endpoint_path' => '/videos/generations',
      'expected_receive_period_in_days' => '1'
    }

    @valid_poll_options = {
      'api_key' => 'test-api-key',
      'model' => 'sora',
      'mode' => 'poll',
      'prompt' => '',
      'generation_id' => 'gen-video-abc123',
      'endpoint_path' => '/videos/generations',
      'expected_receive_period_in_days' => '1'
    }

    @submit_response = File.read(Rails.root.join('spec/data_fixtures/openai_video_generation_submit.json'))
    @complete_response = File.read(Rails.root.join('spec/data_fixtures/openai_video_generation_complete.json'))

    stub_request(:post, 'https://api.openai.com/v1/videos/generations')
      .to_return(body: @submit_response, status: 200, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, 'https://api.openai.com/v1/videos/generations/gen-video-abc123')
      .to_return(body: @complete_response, status: 200, headers: { 'Content-Type' => 'application/json' })
  end

  describe 'submit mode' do
    before do
      @checker = Agents::OpenaiVideoGenerationAgent.new(name: 'Video Gen Agent', options: @valid_submit_options)
      @checker.user = users(:jane)
      @checker.save!

      @event = Event.new
      @event.agent = agents(:jane_weather_agent)
      @event.payload = { 'prompt' => 'A dog surfing on a wave', 'request_id' => 'req-99' }
      @event.save!
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

      it 'requires prompt for submit mode' do
        @checker.options['prompt'] = nil
        expect(@checker).not_to be_valid
      end

      it 'validates mode values' do
        @checker.options['mode'] = 'invalid'
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
      it 'creates an event with generation info' do
        expect {
          @checker.check
        }.to change { Event.count }.by(1)

        event = Event.last
        expect(event.payload['generation_id']).to eq('gen-video-abc123')
        expect(event.payload['status']).to eq('pending')
        expect(event.payload['model']).to eq('sora')
      end
    end

    describe '#receive' do
      it 'creates an event from incoming event' do
        @checker.options['prompt'] = '{{ prompt }}'
        @checker.save!

        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)
      end

      it 'sends authorization header' do
        @checker.receive([@event])

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/videos/generations')
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
        expect(event.payload['request_id']).to eq('req-99')
        # Submit fields present
        expect(event.payload['generation_id']).to eq('gen-video-abc123')
        expect(event.payload['status']).to eq('pending')
      end
    end
  end

  describe 'poll mode' do
    before do
      @checker = Agents::OpenaiVideoGenerationAgent.new(name: 'Video Poll Agent', options: @valid_poll_options)
      @checker.user = users(:jane)
      @checker.save!
    end

    describe '#validation' do
      it 'is valid with correct options' do
        expect(@checker).to be_valid
      end

      it 'requires generation_id for poll mode' do
        @checker.options['generation_id'] = nil
        expect(@checker).not_to be_valid
      end
    end

    describe '#check' do
      it 'creates an event with completed video' do
        expect {
          @checker.check
        }.to change { Event.count }.by(1)

        event = Event.last
        expect(event.payload['generation_id']).to eq('gen-video-abc123')
        expect(event.payload['status']).to eq('complete')
        expect(event.payload['video_url']).to include('sample-video.mp4')
      end
    end

    describe '#receive' do
      it 'polls using generation_id from incoming event' do
        @checker.options['generation_id'] = '{{ generation_id }}'
        @checker.save!

        event = Event.new
        event.agent = agents(:jane_weather_agent)
        event.payload = { 'generation_id' => 'gen-video-abc123' }
        event.save!

        expect {
          @checker.receive([event])
        }.to change { Event.count }.by(1)

        result = Event.last
        expect(result.payload['status']).to eq('complete')
      end
    end

    describe 'output_mode merge in poll mode' do
      before do
        @checker.options['output_mode'] = 'merge'
        @checker.options['generation_id'] = '{{ generation_id }}'
        @checker.save!
      end

      it 'merges original event payload into the poll result' do
        event = Event.new
        event.agent = agents(:jane_weather_agent)
        event.payload = { 'generation_id' => 'gen-video-abc123', 'original_prompt' => 'test' }
        event.save!

        @checker.receive([event])

        result = Event.last
        # Original payload field preserved
        expect(result.payload['original_prompt']).to eq('test')
        # Poll result fields present
        expect(result.payload['status']).to eq('complete')
        expect(result.payload['video_url']).to include('sample-video.mp4')
      end
    end
  end

  describe 'submit_and_poll mode' do
    before do
      @checker = Agents::OpenaiVideoGenerationAgent.new(
        name: 'Video Submit+Poll Agent',
        options: @valid_submit_options.merge('mode' => 'submit_and_poll')
      )
      @checker.user = users(:jane)
      @checker.save!
    end

    describe '#receive' do
      it 'submits and stores pending generation in memory' do
        input_event = Event.new.tap { |e|
          e.agent = agents(:jane_weather_agent)
          e.payload = { 'prompt' => 'A cat playing piano' }
          e.save!
        }

        expect {
          @checker.receive([input_event])
        }.to change { Event.count }.by(1)

        @checker.reload
        expect(@checker.memory['pending_generations']).to be_present
        expect(@checker.memory['pending_generations'].first['generation_id']).to eq('gen-video-abc123')
      end
    end

    describe '#check with pending generations' do
      before do
        @checker.update!(memory: {
          'pending_generations' => [
            { 'generation_id' => 'gen-video-abc123', 'prompt' => 'A cat playing piano', 'submitted_at' => Time.now.iso8601 }
          ]
        })
      end

      it 'polls pending generations and creates events when complete' do
        expect {
          @checker.check
        }.to change { Event.count }.by(1)

        event = Event.last
        expect(event.payload['status']).to eq('complete')
        expect(event.payload['video_url']).to include('sample-video.mp4')

        @checker.reload
        expect(@checker.memory['pending_generations']).to be_empty
      end
    end

    describe '#check with still-pending generations' do
      before do
        pending_response = {
          'id' => 'gen-video-abc123',
          'status' => 'in_progress',
          'model' => 'sora'
        }.to_json

        stub_request(:get, 'https://api.openai.com/v1/videos/generations/gen-video-abc123')
          .to_return(body: pending_response, status: 200, headers: { 'Content-Type' => 'application/json' })

        @checker.update!(memory: {
          'pending_generations' => [
            { 'generation_id' => 'gen-video-abc123', 'prompt' => 'A cat playing piano', 'submitted_at' => Time.now.iso8601 }
          ]
        })
      end

      it 'keeps the generation in pending list' do
        @checker.check
        @checker.reload
        expect(@checker.memory['pending_generations'].length).to eq(1)
      end
    end
  end

  describe '#working?' do
    before do
      @checker = Agents::OpenaiVideoGenerationAgent.new(name: 'Video Agent', options: @valid_submit_options)
      @checker.user = users(:jane)
      @checker.save!
    end

    it 'is not working without recent events' do
      expect(@checker).not_to be_working
    end

    it 'is working with recent events' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  describe 'error handling' do
    before do
      @checker = Agents::OpenaiVideoGenerationAgent.new(name: 'Video Agent', options: @valid_submit_options)
      @checker.user = users(:jane)
      @checker.save!
    end

    it 'handles API errors gracefully' do
      error_response = { 'error' => { 'message' => 'Model not available' } }.to_json
      stub_request(:post, 'https://api.openai.com/v1/videos/generations')
        .to_return(body: error_response, status: 400, headers: { 'Content-Type' => 'application/json' })

      expect {
        @checker.check
      }.not_to change { Event.count }
    end
  end
end
