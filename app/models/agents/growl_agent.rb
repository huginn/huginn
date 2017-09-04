module Agents
  class GrowlAgent < Agent
    include FormConfigurable
    attr_reader :growler

    cannot_be_scheduled!
    cannot_create_events!
    can_dry_run!

    gem_dependency_check { defined?(Growl) }

    description <<-MD
      The Growl Agent sends any events it receives to a Growl GNTP server immediately.

      #{'## Include `ruby-growl` in your Gemfile to use this Agent!' if dependencies_missing?}

      The option `message`, which will hold the body of the growl notification, and the `subject` option,
      which will have the headline of the Growl notification are required. All other options are optional.
      When `callback_url` is set to a URL clicking on the notification will open the link in your default browser.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between
      Events being received by this Agent.

      Have a look at the [Wiki](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) to learn
      more about liquid templating.
    MD

    def default_options
      {
          'growl_server' => 'localhost',
          'growl_password' => '',
          'growl_app_name' => 'HuginnGrowl',
          'growl_notification_name' => 'Notification',
          'expected_receive_period_in_days' => "2",
          'subject' => '{{subject}}',
          'message' => '{{message}}',
          'sticky' => 'false',
          'priority' => '0'
      }
    end

    form_configurable :growl_server
    form_configurable :growl_password
    form_configurable :growl_app_name
    form_configurable :growl_notification_name
    form_configurable :expected_receive_period_in_days
    form_configurable :subject
    form_configurable :message, type: :text
    form_configurable :sticky, type: :boolean
    form_configurable :priority
    form_configurable :callback_url

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless options['growl_server'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "growl_server and expected_receive_period_in_days are required fields")
      end
    end

    def register_growl
      @growler = Growl::GNTP.new(interpolated['growl_server'], interpolated['growl_app_name'])
      @growler.password = interpolated['growl_password']
      @growler.add_notification(interpolated['growl_notification_name'])
    end

    def notify_growl(subject:, message:, priority:, sticky:, callback_url:)
      @growler.notify(interpolated['growl_notification_name'], subject, message, priority, sticky, nil, callback_url)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          register_growl
          message = interpolated[:message]
          subject = interpolated[:subject]
          if message.present? && subject.present?
            log "Sending Growl notification '#{subject}': '#{message}' to #{interpolated(event)['growl_server']} with event #{event.id}"
            notify_growl(subject: subject,
                         message: message,
                         priority: interpolated[:priority].to_i,
                         sticky: boolify(interpolated[:sticky]) || false,
                         callback_url: interpolated[:callback_url].presence)
          else
            log "Event #{event.id} not sent, message and subject expected"
          end
        end
      end
    end
  end
end
