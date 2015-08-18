module Agents
  class GrowlAgent < Agent
    attr_reader :growler

    cannot_be_scheduled!
    cannot_create_events!

    gem_dependency_check { defined?(Growl) }

    description <<-MD
      The Growl Agent sends any events it receives to a Growl GNTP server immediately.

      #{'## Include `ruby-growl` in your Gemfile to use this Agent!' if dependencies_missing?}
      
      It is assumed that events have a `message` or `text` key, which will hold the body of the growl notification, and a `subject` key, which will have the headline of the Growl notification. You can use Event Formatting Agent if your event does not provide these keys.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          'growl_server' => 'localhost',
          'growl_password' => '',
          'growl_app_name' => 'HuginnGrowl',
          'growl_notification_name' => 'Notification',
          'expected_receive_period_in_days' => "2"
      }
    end
    
    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless options['growl_server'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "growl_server and expected_receive_period_in_days are required fields")
      end
    end

    def register_growl
      @growler = Growl.new interpolated['growl_server'], interpolated['growl_app_name'], "GNTP"
      @growler.password = interpolated['growl_password']
      @growler.add_notification interpolated['growl_notification_name']
    end

    def notify_growl(subject, message)
      @growler.notify(interpolated['growl_notification_name'], subject, message)
    end

    def receive(incoming_events)
      register_growl
      incoming_events.each do |event|
        message = (event.payload['message'] || event.payload['text']).to_s
        subject = event.payload['subject'].to_s
        if message.present? && subject.present?
          log "Sending Growl notification '#{subject}': '#{message}' to #{interpolated(event)['growl_server']} with event #{event.id}"
          notify_growl(subject,message)
        else
          log "Event #{event.id} not sent, message and subject expected"
        end
      end
    end
  end
end
