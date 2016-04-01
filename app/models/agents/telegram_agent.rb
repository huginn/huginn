require 'httmultiparty'
require 'open-uri'
require 'tempfile'

module Agents
  class TelegramAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    description <<-MD
      The Telegram Agent receives and collects events and sends them via [Telegram](https://telegram.org/).

      It is assumed that events have either a `text`, `photo`, `audio`, `document` or `video` key. You can use the EventFormattingAgent if your event does not provide these keys.

      The value of `text` key is sent as a plain text message.
      The value of `photo`, `audio`, `document` and `video` keys should be a url whose contents will be sent to you.

      **Setup**

      1. Obtain an `auth_token` by [creating a new bot](https://telegram.me/botfather).
      2. Send a private message to your bot by visiting https://telegram.me/YourHuginnBot
      3. Obtain your private `chat_id` from the recently started conversation by visiting https://api.telegram.org/bot`<auth_token>`/getUpdates
    MD

    def default_options
      {
        auth_token: 'xxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        chat_id: 'xxxxxxxx'
      }
    end

    def validate_options
      errors.add(:base, 'auth_token is required') unless options['auth_token'].present?
      errors.add(:base, 'chat_id is required') unless options['chat_id'].present?
    end

    def working?
      received_event_without_error? && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        receive_event event
      end
    end

    private

    TELEGRAM_ACTIONS = {
      text:     :sendMessage,
      photo:    :sendPhoto,
      audio:    :sendAudio,
      document: :sendDocument,
      video:    :sendVideo
    }.freeze

    def telegram_bot_uri(method)
      "https://api.telegram.org/bot#{interpolated['auth_token']}/#{method}"
    end

    def receive_event(event)
      TELEGRAM_ACTIONS.each do |field, method|
        payload = load_field event, field
        next unless payload
        send_telegram_message method, field => payload
        unlink_file payload if payload.is_a? Tempfile
      end
    end

    def send_telegram_message(method, params)
      params[:chat_id] = interpolated['chat_id']
      HTTMultiParty.post telegram_bot_uri(method), query: params
    end

    def load_field(event, field)
      payload = event.payload[field]
      return false unless payload.present?
      return payload if field == :text
      load_file payload
    end

    def load_file(url)
      file = Tempfile.new [File.basename(url), File.extname(url)]
      file.binmode
      file.write open(url).read
      file.rewind
      file
    end

    def unlink_file(file)
      file.close
      file.unlink
    end
  end
end
