require 'httmultiparty'
require 'open-uri'
require 'tempfile'

module Agents
  class TelegramAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!
    can_dry_run!

    description <<-MD
      The Telegram Agent receives and collects events and sends them via [Telegram](https://telegram.org/).

      It is assumed that events have either a `text`, `photo`, `audio`, `document` or `video` key. You can use the EventFormattingAgent if your event does not provide these keys.

      The value of `text` key is sent as a plain text message. You can also tell Telegram how to parse the message with `parse_mode`, set to either `html` or `markdown`.
      The value of `photo`, `audio`, `document` and `video` keys should be a url whose contents will be sent to you.

      **Setup**

      * Obtain an `auth_token` by [creating a new bot](https://telegram.me/botfather).
      * If you would like to send messages to a public channel:
        * Add your bot to the channel as an administrator
      * If you would like to send messages to a group:
        * Add the bot to the group
      * If you would like to send messages privately to yourself:
        * Open a conservation with the bot by visiting https://telegram.me/YourHuginnBot
      * Send a message to the bot, group or channel.
      * Select the `chat_id` from the dropdown.

      **Options**

      * `caption`: caption for a media content, 0-200 characters
      * `disable_notification`: send a message silently in a channel
      * `disable_web_page_preview`: disable link previews for links in a text message
      * `parse_mode`: parse policy of a text message

      See the official [Telegram Bot API documentation](https://core.telegram.org/bots/api#available-methods) for detailed info.
    MD

    def default_options
      {
        auth_token: 'xxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        chat_id: 'xxxxxxxx'
      }
    end

    form_configurable :auth_token, roles: :validatable
    form_configurable :chat_id, roles: :completable
    form_configurable :caption
    form_configurable :disable_notification, type: :array, values: ['', 'true', 'false']
    form_configurable :disable_web_page_preview, type: :array, values: ['', 'true', 'false']
    form_configurable :parse_mode, type: :array, values: ['', 'html', 'markdown']

    def validate_auth_token
      HTTMultiParty.post(telegram_bot_uri('getMe'))['ok']
    end

    def complete_chat_id
      response = HTTMultiParty.post(telegram_bot_uri('getUpdates'))
      return [] unless response['ok']
      response['result'].map { |update| update_to_complete(update) }.uniq
    end

    def validate_options
      errors.add(:base, 'auth_token is required') unless options['auth_token'].present?
      errors.add(:base, 'chat_id is required') unless options['chat_id'].present?
      errors.add(:base, 'caption should be 200 characters or less') if interpolated['caption'].present? and interpolated['caption'].length > 200
      errors.add(:base, "disable_notification has invalid value: should be 'true' or 'false'") if interpolated['disable_notification'].present? and !%w(true false).include?(interpolated['disable_notification'])
      errors.add(:base, "disable_web_page_preview has invalid value: should be 'true' or 'false'") if interpolated['disable_web_page_preview'].present? and !%w(true false).include?(interpolated['disable_web_page_preview'])
      errors.add(:base, "parse_mode has invalid value: should be 'html' or 'markdown'") if interpolated['parse_mode'].present? and !%w(html markdown).include?(interpolated['parse_mode'])
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

    def configure_params(params)
      params[:disable_notification] = interpolated['disable_notification'] if interpolated['disable_notification'].present?
      if params.has_key?(:text)
        params[:disable_web_page_preview] = interpolated['disable_web_page_preview'] if interpolated['disable_web_page_preview'].present?
        params[:parse_mode] = interpolated['parse_mode'] if interpolated['parse_mode'].present?
      else
        params[:caption] = interpolated['caption'][0..199] if interpolated['caption'].present?
      end

      params
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

    def receive_event(event)
      interpolate_with event do
        messages_send = TELEGRAM_ACTIONS.count do |field, method|
          payload = load_field event, field
          next unless payload
          send_telegram_message method, configure_params(field => payload)
          unlink_file payload if payload.is_a? Tempfile
          true
        end
        error("No valid key found in event #{event.payload.inspect}") if messages_send.zero?
      end
    end

    def send_telegram_message(method, params)
      params[:chat_id] = interpolated['chat_id']
      response = HTTMultiParty.post telegram_bot_uri(method), query: params
      unless response['ok']
        error(response)
      end
    end

    def telegram_bot_uri(method)
      "https://api.telegram.org/bot#{interpolated['auth_token']}/#{method}"
    end

    def unlink_file(file)
      file.close
      file.unlink
    end

    def update_to_complete(update)
      chat = (update['message'] || update.fetch('channel_post', {})).fetch('chat', {})
      {id: chat['id'], text: chat['title'] || "#{chat['first_name']} #{chat['last_name']}"}
    end
  end
end
