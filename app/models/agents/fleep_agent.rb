module Agents
  class FleepAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    description <<-MD
      The Fleep Agent sends messages to a Fleep conversation

      To authenticate you need to set the `fleep_conversation_webhook_url`, you can get one by configuring a generic webhook like described here: [Fleep Webhooks](https://fleep.io/blog/integrations/webhooks/)

      You can provide a `user` and a `message`.

      Have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) to learn more about liquid templating.
    MD

    def default_options
      {
        'fleep_conversation_webhook_url' => '',
        'user' => 'Huginn',
        'message' => 'Hello from Huginn!'
      }
    end

    form_configurable :fleep_conversation_webhook_url
    form_configurable :user
    form_configurable :message, type: :text

    def validate_options
      errors.add(:base, 'you need to specify a fleep_conversation_webhook_url') unless options['fleep_conversation_webhook_url'].present?
    end

    def working?
      (last_receive_at.present? && last_error_log_at.nil?) || (last_receive_at.present? && last_error_log_at.present? && last_receive_at > last_error_log_at)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        mo = interpolated(event)
        post_message_to_fleep(mo[:user], mo[:message])
      end
    end

    private

    def post_message_to_fleep(user, message)
      uri = URI(interpolated[:fleep_conversation_webhook_url])
      Net::HTTP.post_form(uri, user: user, message: message)
    end
  end
end
