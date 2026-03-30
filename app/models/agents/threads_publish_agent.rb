module Agents
  class ThreadsPublishAgent < Agent
    include ThreadsConcern

    cannot_be_scheduled!

    description <<~MD
      The Threads Publish Agent publishes Threads posts from the events it receives.

      #{threads_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Threads in the [Services](/services) section first.

      You must specify a `message` parameter, and you can use [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) to format it.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      If `output_mode` is set to `merge`, the emitted Event will be merged into the original contents of the received Event.

      Note: This agent publishes top-level posts.  It does not fetch your home timeline.
    MD

    event_description <<~MD
      Events look like this:

          {
            "success": true,
            "published_post": "...",
            "published_thread_id": "...",
            "creation_id": "...",
            "agent_id": ...,
            "event_id": ...
          }

          {
            "success": false,
            "error": "...",
            "failed_post": "...",
            "agent_id": ...,
            "event_id": ...
          }

      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def validate_options
      unless options["expected_update_period_in_days"].present?
        errors.add(:base, "expected_update_period_in_days is required")
      end

      output_mode = options["output_mode"].to_s
      if options["output_mode"].present? && !output_mode.include?("{") && !%w[clean merge].include?(output_mode)
        errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
      end

      if options["reply_control"].present? && !options["reply_control"].to_s.include?("{") &&
          !%w[everyone accounts_you_follow mentioned_only].include?(options["reply_control"].to_s)
        errors.add(:base, "reply_control must be everyone, accounts_you_follow, or mentioned_only")
      end
    end

    def working?
      event_created_within?(interpolated["expected_update_period_in_days"]) &&
        most_recent_event &&
        most_recent_event.payload["success"] == true &&
        !recent_error_logs?
    end

    def default_options
      {
        "expected_update_period_in_days" => "10",
        "message" => "{{text}}",
        "reply_to_id" => "",
        "reply_control" => "everyone",
        "output_mode" => "clean",
      }
    end

    def receive(incoming_events)
      incoming_events.first(20).each do |event|
        post_text, reply_to_id, reply_control =
          interpolated(event).values_at("message", "reply_to_id", "reply_control")
        reply_control = reply_control.presence || default_options["reply_control"]
        new_event = interpolated["output_mode"].to_s == "merge" ? event.payload.dup : {}

        begin
          raise "message is required" if post_text.blank?

          creation_id = create_thread(post_text, reply_to_id:, reply_control:)
          thread_id = publish_thread(creation_id)

          new_event.update(
            "success" => true,
            "published_post" => post_text,
            "published_thread_id" => thread_id,
            "creation_id" => creation_id,
            "agent_id" => event.agent_id,
            "event_id" => event.id
          )
        rescue StandardError => e
          new_event.update(
            "success" => false,
            "error" => e.message,
            "failed_post" => post_text,
            "agent_id" => event.agent_id,
            "event_id" => event.id
          )
        end

        create_event payload: new_event
      end
    end

    private

    def create_thread(text, reply_to_id:, reply_control:)
      threads_client.create_text_post(
        text:,
        reply_to_id:,
        reply_control:
      ).fetch(:id)
    end

    def publish_thread(creation_id)
      threads_client.publish_post(user_id: threads_account_id, creation_id:).fetch(:id)
    end
  end
end
