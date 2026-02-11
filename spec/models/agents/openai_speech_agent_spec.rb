require 'rails_helper'

describe Agents::OpenaiSpeechAgent do
  before do
    @valid_transcribe_options = {
      'api_key' => 'test-api-key',
      'mode' => 'transcribe',
      'model' => 'whisper-1',
      'audio_url' => 'https://example.com/audio.wav',
      'expected_receive_period_in_days' => '1'
    }

    @valid_speak_options = {
      'api_key' => 'test-api-key',
      'mode' => 'speak',
      'model' => 'tts-1',
      'input_text' => 'Hello, how are you?',
      'voice' => 'alloy',
      'expected_receive_period_in_days' => '1'
    }

    @transcription_response = File.read(Rails.root.join('spec/data_fixtures/openai_whisper_transcription.json'))

    stub_request(:get, 'https://example.com/audio.wav')
      .to_return(body: 'fake-audio-data', status: 200, headers: { 'Content-Type' => 'audio/wav' })
  end

  describe 'transcribe mode' do
    before do
      @checker = Agents::OpenaiSpeechAgent.new(name: 'Whisper Agent', options: @valid_transcribe_options)
      @checker.user = users(:jane)
      @checker.save!

      @event = Event.new
      @event.agent = agents(:jane_weather_agent)
      @event.payload = { 'audio_url' => 'https://example.com/audio.wav', 'source' => 'podcast' }
      @event.save!

      stub_request(:post, 'https://api.openai.com/v1/audio/transcriptions')
        .to_return(body: @transcription_response, status: 200, headers: { 'Content-Type' => 'application/json' })
    end

    describe '#validation' do
      it 'is valid with correct transcribe options' do
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

      it 'validates mode' do
        @checker.options['mode'] = 'invalid'
        expect(@checker).not_to be_valid
      end

      it 'validates output_mode values' do
        @checker.options['output_mode'] = 'invalid'
        expect(@checker).not_to be_valid
      end
    end

    describe '#check' do
      it 'creates an event with transcription' do
        expect {
          @checker.check
        }.to change { Event.count }.by(1)

        event = Event.last
        expect(event.payload['text']).to eq('The quick brown fox jumped over the lazy dog.')
        expect(event.payload['language']).to eq('en')
      end
    end

    describe '#receive' do
      it 'creates an event with transcription' do
        @checker.options['audio_url'] = '{{ audio_url }}'
        @checker.save!

        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)
      end
    end

    describe 'output_mode merge' do
      before do
        @checker.options['output_mode'] = 'merge'
        @checker.options['audio_url'] = '{{ audio_url }}'
        @checker.save!
      end

      it 'merges original event payload into the emitted event' do
        @checker.receive([@event])

        event = Event.last
        # Original payload field preserved
        expect(event.payload['source']).to eq('podcast')
        # Transcription fields present
        expect(event.payload['text']).to eq('The quick brown fox jumped over the lazy dog.')
      end
    end
  end

  describe 'translate mode' do
    before do
      @checker = Agents::OpenaiSpeechAgent.new(
        name: 'Translate Agent',
        options: @valid_transcribe_options.merge('mode' => 'translate')
      )
      @checker.user = users(:jane)
      @checker.save!

      stub_request(:post, 'https://api.openai.com/v1/audio/translations')
        .to_return(body: @transcription_response, status: 200, headers: { 'Content-Type' => 'application/json' })
    end

    describe '#check' do
      it 'creates an event with translation' do
        expect {
          @checker.check
        }.to change { Event.count }.by(1)

        event = Event.last
        expect(event.payload['text']).to eq('The quick brown fox jumped over the lazy dog.')
        expect(event.payload['language']).to eq('en')
      end
    end
  end

  describe 'speak mode' do
    before do
      @checker = Agents::OpenaiSpeechAgent.new(name: 'TTS Agent', options: @valid_speak_options)
      @checker.user = users(:jane)
      @checker.save!

      @event = Event.new
      @event.agent = agents(:jane_weather_agent)
      @event.payload = { 'text' => 'Hello, how are you?', 'request_id' => 'req-42' }
      @event.save!

      stub_request(:post, 'https://api.openai.com/v1/audio/speech')
        .to_return(body: 'fake-audio-bytes', status: 200, headers: { 'Content-Type' => 'audio/mpeg' })
    end

    describe '#validation' do
      it 'is valid with correct speak options' do
        expect(@checker).to be_valid
      end

      it 'requires input_text for speak mode' do
        @checker.options['input_text'] = nil
        expect(@checker).not_to be_valid
      end

      it 'requires voice for speak mode' do
        @checker.options['voice'] = nil
        expect(@checker).not_to be_valid
      end
    end

    describe '#check' do
      it 'creates an event with audio data' do
        expect {
          @checker.check
        }.to change { Event.count }.by(1)

        event = Event.last
        expect(event.payload['audio_base64']).to be_present
        expect(event.payload['content_type']).to eq('audio/mpeg')
        expect(event.payload['voice']).to eq('alloy')
        expect(event.payload['input_text']).to eq('Hello, how are you?')
      end
    end

    describe '#receive' do
      it 'creates an event with audio data from incoming event' do
        @checker.options['input_text'] = '{{ text }}'
        @checker.save!

        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)
      end
    end

    describe 'output_mode merge' do
      before do
        @checker.options['output_mode'] = 'merge'
        @checker.options['input_text'] = '{{ text }}'
        @checker.save!
      end

      it 'merges original event payload into the emitted event' do
        @checker.receive([@event])

        event = Event.last
        # Original payload field preserved
        expect(event.payload['request_id']).to eq('req-42')
        # TTS fields present
        expect(event.payload['audio_base64']).to be_present
        expect(event.payload['voice']).to eq('alloy')
      end
    end
  end

  describe '#working?' do
    before do
      @checker = Agents::OpenaiSpeechAgent.new(name: 'Speech Agent', options: @valid_transcribe_options)
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
      @checker = Agents::OpenaiSpeechAgent.new(name: 'Speech Agent', options: @valid_transcribe_options)
      @checker.user = users(:jane)
      @checker.save!
    end

    it 'handles audio fetch errors' do
      stub_request(:get, 'https://example.com/audio.wav')
        .to_return(body: 'Not Found', status: 404)

      expect {
        @checker.check
      }.not_to change { Event.count }
    end
  end
end
