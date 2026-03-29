module Agents
  class DropboxWatchAgent < Agent
    include DropboxConcern

    cannot_receive_events!
    default_schedule "every_1m"

    description <<~MD
      The Dropbox Watch Agent watches the given `dir_to_watch` and emits events with the detected changes.

      #{'## Set `DROPBOX_OAUTH_KEY` and `DROPBOX_OAUTH_SECRET` in your environment to use Dropbox Agents.' if dependencies_missing?}

      In the Dropbox App Console, enable the following permissions before authorizing the service for this agent:

      - `account_info.read` to authorize the Dropbox service
      - `files.metadata.read` to list files in `dir_to_watch`

      If you also use the _DropboxFileUrlAgent_, additionally enable:

      - `files.content.read` for temporary links
      - `sharing.read` and `sharing.write` for permanent links

      If you want to watch paths outside your app folder, choose `Full Dropbox` under "Choose the type of access you need" when creating the Dropbox app.

      If you change these permissions, remove the existing Dropbox service from Huginn and authorize it again so the new scopes are included in the access token.
    MD

    event_description <<~MD
      The event payload will contain the following fields:

          {
            "added": [ {
              "path": "/path/to/added/file",
              "rev": "1526952fd5",
              "modified": "2017-10-14T18:39:41Z"
            } ],
            "removed": [ ... ],
            "updated": [ ... ]
          }
    MD

    def default_options
      {
        'dir_to_watch' => '/',
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      errors.add(:base, 'The `dir_to_watch` property is required.') unless options['dir_to_watch'].present?
      errors.add(:base,
                 'Invalid `expected_update_period_in_days` format.') unless options['expected_update_period_in_days'].present? && is_positive_integer?(options['expected_update_period_in_days'])
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !received_event_without_error?
    end

    def check
      current_contents = dropbox.ls(interpolated['dir_to_watch'])
      diff = DropboxDirDiff.new(previous_contents, current_contents)
      create_event(payload: diff.to_hash) unless previous_contents.nil? || diff.empty?

      remember(current_contents)
    end

    private

    def previous_contents
      self.memory['contents']
    end

    def remember(contents)
      self.memory['contents'] = contents
    end

    # == Auxiliary classes ==

    class DropboxDirDiff
      def initialize(previous, current)
        @previous = previous || []
        @current = current || []
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
          previous_entry = find_by_path(@previous, current_entry['path'])
          (current_entry != previous_entry) && !previous_entry.nil?
        end

        updated_entries = @updated + @previous.select do |previous_entry|
          find_by_path(@updated, previous_entry['path'])
        end

        @added = @current - @previous - updated_entries
        @removed = @previous - @current - updated_entries
      end

      def find_by_path(array, path)
        array.find { |entry| entry['path'] == path }
      end
    end
  end
end
