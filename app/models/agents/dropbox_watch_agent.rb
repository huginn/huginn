module Agents
  class DropboxWatchAgent < Agent
    cannot_receive_events!
    default_schedule "every_1m"

    description <<-MD
      The _DropboxWatchAgent_ watches the given `dir_to_watch` and emits events with the detected changes.
      It requires a [Dropbox App](https://www.dropbox.com/developers/apps) and its `access_token`, which will be used to authenticate on your account.
    MD

    event_description <<-MD
      The event payload will contain the following fields, when applicable:
      ```
      {
        "added": [ "path/to/new/file" ],
        "removed": [ "path/to/removed/file" ],
        "updated": [ "path/to/updated/file" ]
      }
      ```
    MD

    def default_options
      {
        access_token: 'your_dropbox_app_access_token',
        dir_to_watch: '/',
        expected_update_period_in_days: 1
      }
    end

    def validate_options
      errors.add(:base, 'The `access_token` property is required.') unless options['access_token'].present?
      errors.add(:base, 'The `dir_to_watch` property is required.') unless options['dir_to_watch'].present?
      errors.add(:base, 'Invalid `expected_update_period_in_days` format.') unless options['expected_update_period_in_days'].present? && is_positive_integer?(options['expected_update_period_in_days'])
    end

    def working?
      event_created_within?(interpolated[:expected_update_period_in_days]) && !received_event_without_error?
    end

    private

    def is_positive_integer?(value)
      Integer(value) >= 0
    rescue
      false
    end

  end
end
