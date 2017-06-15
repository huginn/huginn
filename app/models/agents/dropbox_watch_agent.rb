module Agents
  class DropboxWatchAgent < Agent
    include DropboxConcern

    cannot_receive_events!
    default_schedule "every_1m"

    description <<-MD
      The Dropbox Watch Agent watches the given `dir_to_watch` and emits events with the detected changes.
      
      #{'## Include the `dropbox-api` and `omniauth-dropbox` gems in your `Gemfile` and set `DROPBOX_OAUTH_KEY` and `DROPBOX_OAUTH_SECRET` in your environment to use Dropbox Agents.' if dependencies_missing?}
    MD

    event_description <<-MD
      The event payload will contain the following fields:

          {
            "added": [ {
              "path": "/path/to/added/file",
              "rev": "1526952fd5",
              "modified": "Fri, 10 Oct 2014 19:00:43 +0000"
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
      errors.add(:base, 'Invalid `expected_update_period_in_days` format.') unless options['expected_update_period_in_days'].present? && is_positive_integer?(options['expected_update_period_in_days'])
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !received_event_without_error?
    end

    def check
      current_contents = ls(interpolated['dir_to_watch'])
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

    def ls(dir_to_watch)
      dropbox.ls(dir_to_watch).map { |entry| slice_json(entry, 'path', 'rev', 'modified') }
    end

    def slice_json(json, *keys)
      keys.each_with_object({}){|key, hash| hash[key.to_s] = json[key.to_s]}
    end

    def previous_contents
      self.memory['contents']
    end

    def remember(contents)
      self.memory['contents'] = contents
    end

    # == Auxiliary classes ==

    class DropboxDirDiff
      def initialize(previous, current)
        @previous, @current = [previous || [], current || []]
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
