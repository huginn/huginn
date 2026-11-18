require 'rails_helper'

describe GoogleCalendar do
  let(:scope) { Google::Apis::CalendarV3::AUTH_CALENDAR }
  let(:email) { 'calendar@example.test' }

  describe '.new' do
    it 'requires explicit service account credentials' do
      expect(Google::Auth).not_to receive(:get_application_default)

      expect {
        described_class.new({ 'google' => {} }, Rails.logger)
      }.to raise_error(ArgumentError, 'Google Calendar requires agent service account credentials')
    end

    it 'passes an inline key to googleauth without changing the environment' do
      expect(ENV).not_to receive(:[]=)
      expect(ENV).not_to receive(:delete)
      expect(Google::Auth::ServiceAccountCredentials).to receive(:make_creds) do |json_key_io:, scope:|
        expect(scope).to eq(Google::Apis::CalendarV3::AUTH_CALENDAR)
        expect(JSON.parse(json_key_io.read)).to eq(
          'type' => 'service_account',
          'client_email' => email,
          'private_key' => "test\nkey"
        )
      end

      described_class.new({ 'google' => { 'key' => 'test\nkey', 'service_account_email' => email } }, Rails.logger)
    end

    context 'with a server-side key file' do
      let(:path) { '/example/calendar.json' }
      let(:config) { { 'google' => { 'key_file' => path } } }

      before do
        allow(ENV).to receive(:[]).and_call_original
      end

      it 'rejects the path before opening it by default' do
        allow(ENV).to receive(:[]).with('ENABLE_INSECURE_AGENTS').and_return('false')
        expect(File).not_to receive(:open).with(path, 'r')

        expect {
          described_class.new(config, Rails.logger)
        }.to raise_error(ArgumentError, /Google Calendar key_file is disabled/)
      end

      it 'loads the configured file when insecure agents are enabled' do
        allow(ENV).to receive(:[]).with('ENABLE_INSECURE_AGENTS').and_return('true')
        file = StringIO.new
        expect(File).to receive(:open).with(path, 'r').and_yield(file)
        expect(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).with(json_key_io: file, scope:)

        described_class.new(config, Rails.logger)
      end
    end
  end
end
