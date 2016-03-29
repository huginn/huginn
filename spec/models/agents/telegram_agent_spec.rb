require 'rails_helper'

describe Agents::TelegramAgent do
  before do
    default_options = {
      auth_token: 'xxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      chat_id: 'xxxxxxxx'
    }
    @checker = Agents::TelegramAgent.new name: 'Telegram Tester', options: default_options
    @checker.user = users(:bob)
    @checker.save!

    @sent_messages = []
    stub_methods
  end

  def stub_methods
    stub.any_instance_of(Agents::TelegramAgent).send_telegram_message do |method, params|
      @sent_messages << { method => params }
    end

    stub.any_instance_of(Agents::TelegramAgent).load_file do |_url|
      :stubbed_file
    end
  end

  def event_with_payload(payload)
    event = Event.new
    event.agent = agents(:bob_weather_agent)
    event.payload = payload
    event.save!
    event
  end

  describe 'validation' do
    before do
      expect(@checker).to be_valid
    end

    it 'should validate presence of of auth_token' do
      @checker.options[:auth_token] = ''
      expect(@checker).not_to be_valid
    end

    it 'should validate presence of of chat_id' do
      @checker.options[:chat_id] = ''
      expect(@checker).not_to be_valid
    end
  end

  describe '#receive' do
    it 'processes multiple events properly' do
      event_0 = event_with_payload text: 'Looks like its going to rain'
      event_1 = event_with_payload text: 'Another text message'
      @checker.receive [event_0, event_1]

      expect(@sent_messages).to eq([
        { sendMessage: { text: 'Looks like its going to rain' } },
        { sendMessage: { text: 'Another text message' } }
      ])
    end

    it 'accepts photo key and uses :send_photo to send the file' do
      event = event_with_payload photo: 'https://example.com/image.png'
      @checker.receive [event]

      expect(@sent_messages).to eq([{ sendPhoto: { photo: :stubbed_file } }])
    end

    it 'accepts audio key and uses :send_audio to send the file' do
      event = event_with_payload audio: 'https://example.com/sound.mp3'
      @checker.receive [event]

      expect(@sent_messages).to eq([{ sendAudio: { audio: :stubbed_file } }])
    end

    it 'accepts document key and uses :send_document to send the file' do
      event = event_with_payload document: 'https://example.com/document.pdf'
      @checker.receive [event]

      expect(@sent_messages).to eq([{ sendDocument: { document: :stubbed_file } }])
    end

    it 'accepts video key and uses :send_video to send the file' do
      event = event_with_payload video: 'https://example.com/video.avi'
      @checker.receive [event]

      expect(@sent_messages).to eq([{ sendVideo: { video: :stubbed_file } }])
    end
  end

  describe '#working?' do
    it 'is not working without having received an event' do
      expect(@checker).not_to be_working
    end

    it 'is working after receiving an event without error' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end
end
