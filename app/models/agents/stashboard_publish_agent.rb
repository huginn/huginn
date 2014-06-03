require "stashboard"

module Agents
  class StashboardPublishAgent < Agent
    include LiquidInterpolatable

    cannot_be_scheduled!

    description <<-MD
      The StashboardPublishAgent updates stashboard service statuses from the events it receives.

      Stashboard credentials must be supplied as [credentials](/user_credentials) called
      `stashboard_oauth_url`, `stashboard_oauth_token`, and `stashboard_oauth_token_secret`.

      You must also specify a `service`, `status`, and `message` parameters, and you can use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) to format the message.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      If you will be receiving events with `services` and `status` options that do not already exist in Stashboard, you can set the `addifnodef` (add if not defined) option to true and optionally define `svcdesc`, `statdesc`, `statimage`, and `statlevel` to pass along service description, status description, status image choice, and status level choice for dynamically created services and alerts.

      The `message`, `svcdesc`, and `statdesc` options can use Liquid Interpolate to populate values.
    MD

    def default_options
      {
        'expected_update_period_in_days' => "7",
        'service' => "",
        'status' => "",
        'message' => "{{message}}",
        'addifnodef' => "false",
      }
    end

    def validate_options
      # message is an optional option in Stashboard, so no need to validate it here.
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
      errors.add(:base, "service is required") unless options['service'].present?
      errors.add(:base, "status is required") unless options['status'].present?
      errors.add(:base, "addifnodef is required") unless options["addifnodef"].present?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 30
        incoming_events = incoming_events.first(30)
      end
      # Initialize globally used consumer and token clients
      oauth_key = credential("stashboard_oauth_token")
      oauth_secret = credential("stashboard_oauth_token_secret")
      base = credential("stashboard_oauth_url")
      @sb = Stashboard::Stashboard.new(base, oauth_key, oauth_secret)
      # Loop through remaining events
      incoming_events.each do |event|
        options['addifnodef'] = (event.payload['addifnodef'] == 'true') ? true : false
        options['svcdesc'] = interpolate_string("{{svcdesc}}", event.payload)

        options["statdesc"] = interpolate_string("{{statdesc}}", event.payload)
        options["statlevel"] = event.payload['statlevel'].presence || "NORMAL"
        options["statimage"] = event.payload['statimage'].presence || ""

        svc = event.payload['service']
        status = event.payload['status']
        message_text = interpolate_string(options['message'], event.payload)
        begin
          sb_result = publish_status(svc, status, message_text)
          create_event :payload => {
            'success' => true,
            'result' => sb_result,
            'published_sb_service' => svc,
            'published_sb_status' => status,
            'published_sb_message' => message_text,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        rescue StandardError => e
          create_event :payload => {
            'success' => false,
            'error' => e.message,
            'backtrace' => e.backtrace.join("\n"),
            'published_sb_status' => message_text,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        end
      end
    end

    def service_by_name(name)
        @sb.services.each do |svc|
            if svc.has_key?("name")
              if svc["name"].casecmp(name) == 0
                  return svc
              end
            end
        end
        return nil
    end

    def random_image
        images = @sb.status_images
        img = images[rand(images.length)]
        return img["name"]
    end

    def status_by_name(name)
        @sb.statuses.each do |status|
            if status.has_key?("name")
              if status["name"].casecmp(name) == 0
                  return status
              end
            end
        end
        return nil
    end

    def publish_status(name, status, text)
        svc = service_by_name(name)
        # Create this service if it wasn't found and we were told to create it
        if options["addifnodef"] and svc.nil?
            options["svcdesc"] = name unless !options["svcdesc"].empty?
            svc = @sb.create_service(name, options["svcdesc"])
        end
        stat = status_by_name(status)
        if options["addifnodef"] and stat.nil?
           options["statdesc"] = name unless !options["statdesc"].empty?
           options["statimage"] = random_image unless !options["statimage"].empty?
           stat = @sb.create_status(status, options["statdesc"], options["statlevel"], options["statimage"])
        end
        # Now set the service status
        return @sb.create_event(svc['id'], stat['id'], text)
    end
  end
end
