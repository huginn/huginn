module Agents
  class RaindropBookmarksAgent < Agent
    include RaindropConcern

    can_dry_run!
    cannot_receive_events!

    description <<~MD
      The Raindrop Bookmarks Agent watches Raindrop.io bookmarks and emits events for new raindrops.

      #{raindrop_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Raindrop in the [Services](/services) section first.

      Set `collection_id` to the collection you want to watch.  Use `0` for all bookmarks, `-1` for Unsorted, or a specific collection ID.

      Set `search` to a Raindrop search query to filter bookmarks.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description <<~MD
      Events are the raw JSON provided by the Raindrop API.  They look like:

          {
            "_id": 123,
            "link": "https://example.com/",
            "title": "Example",
            "excerpt": "Description",
            "tags": ["reading"],
            "created": "2026-01-01T00:00:00.000Z",
            "lastUpdate": "2026-01-01T00:00:00.000Z",
            "collection": {
              "$id": 0
            }
          }
    MD

    default_schedule "every_1h"

    def working?
      event_created_within?(interpolated["expected_update_period_in_days"]) && !recent_error_logs?
    end

    def default_options
      {
        "collection_id" => "0",
        "search" => "",
        "limit" => "50",
        "sort" => "-created",
        "nested" => "false",
        "expected_update_period_in_days" => "2",
      }
    end

    def validate_options
      errors.add(:base, "collection_id is required") if options["collection_id"].blank?
      if options["expected_update_period_in_days"].blank?
        errors.add(:base, "expected_update_period_in_days is required")
      end

      if limit.present? && (!(1..50).cover?(limit.to_i) || limit.to_s != limit.to_i.to_s)
        errors.add(:base, "limit must be an integer between 1 and 50")
      end
    end

    def check
      raindrops = fetch_raindrops
      latest_created_at = nil
      latest_ids = Set.new

      sorted_raindrops = raindrops.sort_by do |raindrop|
        [parse_timestamp(raindrop[:created]) || Time.at(0), raindrop[:_id].to_s]
      end

      sorted_raindrops.each do |raindrop|
        created_at = parse_timestamp(raindrop[:created])
        next unless created_at
        next if already_seen?(raindrop, created_at)

        create_event payload: raindrop

        case
        when latest_created_at.nil? || created_at > latest_created_at
          latest_created_at = created_at
          latest_ids.clear
          latest_ids.add(raindrop[:_id].to_s)
        when created_at == latest_created_at
          latest_ids.add(raindrop[:_id].to_s)
        end
      end

      return unless latest_created_at

      memory["since"] = latest_created_at.iso8601
      memory["since_ids"] = latest_ids.to_a
      save!
    end

    private

    def fetch_raindrops
      raindrop_client.raindrops(
        collection_id: interpolated["collection_id"],
        perpage: limit,
        search: interpolated["search"].presence,
        sort: interpolated["sort"].presence || default_options["sort"],
        nested: truthy?(interpolated["nested"])
      )
    end

    def limit
      interpolated["limit"].presence || default_options["limit"]
    end

    def already_seen?(raindrop, created_at)
      since = parse_timestamp(memory["since"])
      return false unless since
      return true if created_at < since

      created_at == since && since_ids.include?(raindrop[:_id].to_s)
    end

    def parse_timestamp(value)
      Time.zone.parse(value) if value.present?
    rescue StandardError
      nil
    end

    def since_ids
      @since_ids ||= Set.new(Array(memory["since_ids"]))
    end
  end
end
