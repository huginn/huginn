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
    MD

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
      errors.add(:base, "service is required") unless options['service'].present?
      errors.add(:base, "status is required") unless options['status'].present?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => "365",
        'service' => "{{service}}",
        'status' => "{{status}}",
        'message' => "{{message}}",
        'addifnodef' => false,
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 20
        incoming_events = incoming_events.first(20)
      end
      # Initialize globally used consumer and token clients
      oauth_key = credential("stashboard_oauth_token")
      oauth_secret = credential("stashboard_oauth_token_secret")
      base = credential("stashboard_oauth_url")
      @sb = Stashboard::Stashboard.new(base, oauth_key, oauth_secret)
      # Loop through remainin events
      incoming_events.each do |event|
        options['addifnodef'] = (interpolate_string("{{addifnodef}}", event.payload) == 'true') || false
        options['svcdesc'] = interpolate_string("{{svcdesc}}", event.payload)

        options["statdesc"] = interpolate_string("{{statdesc}}", event.payload)
        options["statlevel"] = interpolate_string("{{statlevel}}", event.payload)
        options["statimage"] = interpolate_string("{{statimage}}", event.payload)

        svc = interpolate_string(options['service'], event.payload)
        status = interpolate_string(options['status'], event.payload)
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
        rescue Exception => e
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
        img = @sb.status_images[rand(images.length)]
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
        # log "AddIfNoDef: #{options['addifnodef']}"
        if options["addifnodef"] and svc.nil?
            options["svcdesc"] = name unless !options["svcdesc"].empty?
            svc = @sb.create_service(name, options["svcdesc"])
            # log "Finished create_service: #{name}, #{options['svcdesc']}"
        end
        stat = status_by_name(status)
        if options["addifnodef"] and stat.nil?
           options["statdesc"] = name unless !options["statdesc"].empty?
           options["statlevel"] = "NORMAL" unless !options["statlevel"].empty?
           options["statimage"] = random_image unless !options["statimage"].empty?
           stat = @sb.create_status(status, options["statdesc"], options["statlevel"], options["statimage"])
           # log "Finished create_status: #{status}, #{options['statdesc']}, #{options['statlevel']}, #{options['statimage']}"
        end
        # log "SVC: #{svc}"
        # Now set the service status
        return @sb.create_event(svc['id'], stat['id'], text)
    end
  end
end
