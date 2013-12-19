module Agents
  class WebhookAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      Use this Agent to create events by receiving webhooks from any source.

      Options:

        * `secret` - A token that the host will provide for authentication.
    MD

    def default_options
      { "secret" => "supersecretstring", }
    end

    def receive_webhook(params)
      return ["Not Authorized", 401] unless params[:secret] == options[:secret]

      create_event(:payload => params[:payload])

      ['Event Created', 201]
    end

    def working?
      true
    end

    def validate_options
      unless options[:secret].present?
        errors.add(:base, "Must specify a :secret for 'Authenticating' requests")
      end
    end
  end
end
