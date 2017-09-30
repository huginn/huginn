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
    before do
      @sent_messages = []
      stub_methods
    end

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

    it 'creates a log entry when no key of the received event was useable' do
      event = event_with_payload test: '1234'
      expect {
        @checker.receive [event]
      }.to change(AgentLog, :count).by(1)
    end
  end

  it 'creates and error log if the request fails' do
    event = event_with_payload text: 'hello'
    stub_request(:post, "https://api.telegram.org/botxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/sendMessage").
      with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(status: 200, body: '{"ok": false}', headers: {'Content-Type' => 'application/json'})

    expect {
      @checker.receive [event]
    }.to change(AgentLog, :count).by(1)
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

  describe '#complete_chat_id' do
    it 'returns a list of all recents chats, groups and channels' do
      stub_request(:post, "https://api.telegram.org/botxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/getUpdates").
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: '{"ok":true,"result":[{"update_id":252965475,"message":{"message_id":15,"from":{"id":97201077,"is_bot":false,"first_name":"Dominik","last_name":"Sander","language_code":"en-US"},"chat":{"id":97201077,"first_name":"Dominik","last_name":"Sander","type":"private"},"date":1506774710,"text":"test"}},{"update_id":252965476,"channel_post":{"message_id":4,"chat":{"id":-1001144599139,"title":"Much channel","type":"channel"},"date":1506782283,"text":"channel"}},{"update_id":252965477,"message":{"message_id":18,"from":{"id":97201077,"is_bot":false,"first_name":"Dominik","last_name":"Sander","language_code":"en-US"},"chat":{"id":-217850512,"title":"Just a test","type":"group","all_members_are_administrators":true},"date":1506782504,"left_chat_participant":{"id":136508315,"is_bot":true,"first_name":"Huginn","username":"HuginnNotificationBot"},"left_chat_member":{"id":136508315,"is_bot":true,"first_name":"Huginn","username":"HuginnNotificationBot"}}}]}', headers: {'Content-Type' => 'application/json'})

      expect(@checker.complete_chat_id).to eq([{:id=>97201077, :text=>"Dominik Sander"},
                                               {:id=>-1001144599139, :text=>"Much channel"},
                                               {:id=>-217850512, :text=>"Just a test"}])
    end
  end

  describe '#validate_auth_token' do
    it 'returns true if the token is valid' do
      stub_request(:post, "https://api.telegram.org/botxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/getMe").
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: '{"ok": true}', headers: {'Content-Type' => 'application/json'})

      expect(@checker.validate_auth_token).to be_truthy
    end

    it 'returns false if the token is invalid' do
      stub_request(:post, "https://api.telegram.org/botxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/getMe").
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: "{}")

      expect(@checker.validate_auth_token).to be_falsy
    end
  end
end
