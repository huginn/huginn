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

      The value of `text` key is sent as a plain text message. You can also tell Telegram how to parse the message with `parse_mode`, set to either `html` or `markdown`.
      The value of `photo`, `audio`, `document` and `video` keys should be a url whose contents will be sent to you.

      **Setup**

      1. Obtain an `auth_token` by [creating a new bot](https://telegram.me/botfather).
      2a. If you would like to send messages to a public channel:
        1. Add your bot to the channel as an administrator
        2. Set `chat_id` to the name of your channel - e.g. `@YourHugginChannel`
      2b. If you would like to send messages to a group:
        1. Add the bot to the group
        2. Obtain your group `chat_id` from the recently started conversation by visiting https://api.telegram.org/bot`<auth_token>`/getUpdates
      2c. If you would like to send messages privately to yourself:
        1. Send a private message to your bot by visiting https://telegram.me/YourHuginnBot
        2. Obtain your private `chat_id` from the recently started conversation by visiting https://api.telegram.org/bot`<auth_token>`/getUpdates
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
      errors.add(:base, 'parse_mode has invalid value: should be html or markdown') if interpolated['parse_mode'].present? and !['html', 'markdown'].include? interpolated['parse_mode']
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
      params[:parse_mode] = interpolated['parse_mode'] if interpolated['parse_mode'].present?
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
