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

    def check
      api = DropboxAPI.new(interpolated[:access_token])
      current_contents = api.dir(interpolated[:dir_to_watch])

      diff = DropboxDirDiff.new(previous_contents, current_contents)
      create_event(payload: diff.to_hash) unless previous_contents.nil? || diff.empty?

      remember(current_contents)
    end

    private

    def is_positive_integer?(value)
      Integer(value) >= 0
    rescue
      false
    end

    def previous_contents
      self.memory['contents']
    end

    def remember(contents)
      self.memory['contents'] = contents
    end

    # == Auxiliary classes ==

    class DropboxAPI
      def initialize(access_token)
      end
    end

    class DropboxDirDiff
      def initialize(previous, current)
        @previous, @current = [previous, current]
      end

      def empty?
        (@previous == @current)
      end

      def to_hash
        calculate_diff
        { added: @added, removed: @removed, updated: @updated }
      end

      private

      def calculate_diff
        @updated = @current.select do |current_entry|
          previous_entry = find_by_path(@previous, current_entry[:path])
          (current_entry != previous_entry) && !previous_entry.nil?
        end

        updated_entries = @updated + @previous.select do |previous_entry|
          find_by_path(@updated, previous_entry[:path])
        end

        @added = @current - @previous - updated_entries
        @removed = @previous - @current - updated_entries
      end

      def find_by_path(array, path)
        array.find { |entry| entry[:path] == path }
      end
    end

  end

end
