require "tempfile"
require "faraday"
require "uri"
require "securerandom"
module Agents
  class FileDownloadAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      File download agent is designed to download things and write the content to files. Right now it blocks, so you should be very careful what are you downloading.
      # Required parameters
      * url: url to get

      # Optional parameters
      * destination: where to save the file, if omitted tempfile will be created.
      * mode: if you set to `merge` it will keep the original event and it will add the destination where we saved the file, by default it is `clean`
    MD

    def default_options
      {
          "expected_update_period_in_days" => 10,
          "url" => "{{ url }}",
          "destination" => "{{ destination }}",
          "mode" => "clean"
      }
    end

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
      errors.add(:base, "url is required") unless options['url'].present?
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['destination'] && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        timeout = interpolated(event)['timeout'] || 10
        mode = interpolated(event)['mode']
        destination = interpolated(event)['destination']
        url = interpolated(event)['url']
        begin
          response = download(url)
          path = save(destination, response.body)

          if mode == "merge"
            create_event :payload => event.payload.dup.merge({
              "destination" => path
            })
          else
            create_event :payload => {
              "destination" => path
            }
          end
        rescue => e
          log("Failed to download #{url} to #{destination || '<tmp>'}: #{e}")
        end
      end
    end
    def save(destination, content)
      begin
        if !destination
          handle = Tempfile.new(SecureRandom.hex, :encoding => 'ascii-8bit')
          destination = handle.path
        else
          handle = File.open(destination, 'wb')
        end
        handle.write(content)
        handle.path
      rescue => e
        raise e
      ensure
        handle.close unless handle.nil?
      end
    end

    def download(url)
      uri = URI.parse(url)
      conn = Faraday.new "#{uri.scheme}://#{uri.host}" do |f|
        f.adapter :em_http
      end

      conn.get "#{uri.path}?#{uri.query}"
    end
  end
end
