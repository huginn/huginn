require 'uri'

module Agents
  class PostAgent < Agent
    include EventHeadersConcern
    include WebRequestConcern

    MIME_RE = /\A\w+\/.+\z/

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        A Matrix Agent sends events to Matrix (matrix.org) rooms.
      MD
    end

    def default_options
      {
        'homeserver_url' => 'https://matrix-client.matrix.org',
      }
    end

    def validate_options
      unless options['homeserver_url'].present?
        errors.add(:base, 'homeserver_url is required')
      end

      unless options['auth_token'].present?
        errors.add(:base, 'auth_token is required')
      end

      unless options['room_id'].present?
        errors.add(:base, 'room_id is required')
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          handle event
        end
      end
    end

    private

    def handle(event)
      headers = {
        'Authorization' => "Bearer #{options['auth_token']}",
        'Content-Type' => 'application/json: charset=utf-8',
      }
      payload = {
        'msgtype' => 'm.notice',
        'body' => interpolated(event.body),
      }
      # https://github.com/ara4n/random/blob/master/bashtrix.sh
      txnid = "m.#{Time.now.to_i}"
      # https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-rooms-roomid-send-eventtype-txnid
      url = URI.join(options['homeserver_url'], '/_matrix/client/r0/rooms/',
                     options['room_id'], '/send/m.room.message/', txnid)

      resp = faraday.put(url, payload, headers)
    end
  end
end
