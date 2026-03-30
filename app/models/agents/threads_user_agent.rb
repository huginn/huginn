module Agents
  class ThreadsUserAgent < Agent
    include ThreadsConcern

    can_dry_run!
    cannot_receive_events!

    description <<~MD
      The Threads User Agent follows the posts created by a specific Threads user, or your authenticated Threads account by default.

      #{threads_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Threads in the [Services](/services) section first.

      Set `user_id` to a Threads user ID to follow that user's posts.  Leave it blank to follow the authenticated user's own posts.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Set `starting_at` to the date/time you want to start receiving posts from.  Defaults to the Agent's `created_at`.

      Note: Threads' public API does not expose a home timeline/feed equivalent, so this agent only follows one user's own posts.
    MD

    event_description <<~MD
      Events are the raw JSON provided by the Threads API.  They look like:

          {
            "id": "1234567",
            "media_product_type": "THREADS",
            "media_type": "TEXT_POST",
            "permalink": "https://www.threads.net/@threadsapitestuser/post/abcdefg",
            "owner": {
              "id": "1234567"
            },
            "username": "threadsapitestuser",
            "text": "Hello World",
            "timestamp": "2023-10-09T23:18:27+0000",
            "shortcode": "abcdefg",
            "is_quote_post": false
          }
    MD

    default_schedule "every_1h"

    def working?
      event_created_within?(interpolated["expected_update_period_in_days"]) && !recent_error_logs?
    end

    def default_options
      {
        "user_id" => "",
        "limit" => "25",
        "expected_update_period_in_days" => "2",
      }
    end

    def validate_options
      if options["expected_update_period_in_days"].blank?
        errors.add(:base, "expected_update_period_in_days is required")
      end

      limit = interpolated["limit"].presence || options["limit"]
      if limit.present? && (!(1..100).cover?(limit.to_i) || limit.to_i.to_s != limit.to_s)
        errors.add(:base, "limit must be an integer between 1 and 100")
      end

      if options["starting_at"].present? && parse_timestamp(options["starting_at"]).nil?
        errors.add(:base, "Error parsing starting_at")
      end
    end

    def check
      posts = fetch_posts
      latest_timestamp = nil
      latest_ids = Set.new

      posts.sort_by { |post| [parse_timestamp(post[:timestamp]) || Time.at(0), post[:id]] }.each do |post|
        timestamp = parse_timestamp(post[:timestamp])
        next unless timestamp && timestamp >= starting_at
        next if already_seen?(post, timestamp)

        create_event payload: post

        if latest_timestamp.nil? || timestamp > latest_timestamp
          latest_timestamp = timestamp
          latest_ids.clear
          latest_ids.add(post[:id])
        elsif timestamp == latest_timestamp
          latest_ids.add(post[:id])
        end
      end

      if latest_timestamp
        memory["since"] = latest_timestamp.iso8601
        memory["since_ids"] = latest_ids.to_a
        save!
      end
    end

    private

    def fetch_posts
      threads_client.posts(
        user_id: target_user_id,
        fields: THREADS_DEFAULT_FIELDS.join(","),
        limit: request_limit,
        since: memory["since"].presence
      )
    end

    def target_user_id
      interpolated["user_id"].presence || threads_user_id.presence || "me"
    end

    def request_limit
      interpolated["limit"].presence || default_options["limit"]
    end

    def starting_at
      @starting_at ||=
        parse_timestamp(interpolated["starting_at"]) || created_at || Time.zone.now
    end

    def already_seen?(post, timestamp)
      since = parse_timestamp(memory["since"])
      return false unless since
      return true if timestamp < since

      timestamp == since && since_ids.include?(post[:id])
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
