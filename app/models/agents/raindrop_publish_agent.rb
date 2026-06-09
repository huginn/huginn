module Agents
  class RaindropPublishAgent < Agent
    include RaindropConcern

    cannot_be_scheduled!
    can_dry_run!

    description <<~MD
      The Raindrop Publish Agent saves links to Raindrop.io from incoming events.

      #{raindrop_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Raindrop in the [Services](/services) section first.

      You must specify `link`.  You can use Liquid in `link`, `title`, `excerpt`, `note`, `tags`, and `collection_id`.  Use `-1` for Unsorted or a specific collection ID.

      Set `output_mode` to `merge` to merge the emitted Event into the original received Event.
    MD

    event_description <<~MD
      Events look like this:

          {
            "success": true,
            "raindrop": {
              "_id": 123,
              "link": "https://example.com/",
              "title": "Example"
            },
            "agent_id": 1,
            "event_id": 2
          }
    MD

    def default_options
      {
        "link" => "{{url}}",
        "title" => "{{title}}",
        "excerpt" => "",
        "note" => "",
        "tags" => "",
        "collection_id" => "-1",
        "important" => "false",
        "please_parse" => "true",
        "output_mode" => "clean",
      }
    end

    def validate_options
      errors.add(:base, "link is required") if options["link"].blank?

      output_mode = options["output_mode"].to_s
      if options["output_mode"].present? && !output_mode.include?("{") && !%w[clean merge].include?(output_mode)
        errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
      end
    end

    def working?
      most_recent_event && most_recent_event.payload["success"] == true && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = interpolated(event)
        new_event = payload["output_mode"].to_s == "merge" ? event.payload.dup : {}

        begin
          attributes = raindrop_attributes(payload)
          raindrop = raindrop_client.create_raindrop(attributes)
          new_event.update(
            "success" => true,
            "raindrop" => raindrop,
            "agent_id" => event.agent_id,
            "event_id" => event.id
          )
        rescue StandardError => e
          new_event.update(
            "success" => false,
            "error" => e.message,
            "failed_link" => payload["link"],
            "agent_id" => event.agent_id,
            "event_id" => event.id
          )
        end

        create_event payload: new_event
      end
    end

    private

    def raindrop_attributes(payload)
      link = payload["link"].presence
      raise "link is required" if link.blank?

      {
        link:,
        title: payload["title"].presence,
        excerpt: payload["excerpt"].presence,
        note: payload["note"].presence,
        tags: tags(payload["tags"]),
        collection: collection(payload["collection_id"]),
        important: truthy?(payload["important"]),
        pleaseParse: truthy?(payload["please_parse"]) ? {} : nil,
      }
    end

    def tags(value)
      value.to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def collection(collection_id)
      return if collection_id.blank?

      { "$id": collection_id.to_i }
    end
  end
end
