module Agents
  class TrelloNotificationAgent < Agent
    no_bulk_receive!
    default_schedule "every_1h"
    cannot_receive_events!
    gem_dependency_check { defined?(Trello) }

    description <<-MD
      The Trello Notification agent allows you to get notifications from Trello.

      To use the Trello Notification agent you will first need to sign into your Trello account.
      Once you have signed in go to the following url https://trello.com/app-key and copy the key.
      This will be used as the agent "public_key".

      Next on the same page click on the "Token" link and copy the token displayed. This will be used as the agent "member_token".

      Additionally you can specify the Trello board name. This will restrict the agent to notifications of that particular board. If no board is specified, then notifications from all boards is returned.

      You will also need to specify you Trello username as "username". If no username is specified it will get a list of notifications for all members of the specified board.

      Finally you will also need to specify the max age of the notifications to retrieve. By default this is "0" which will retrieve all notifications. 1 retrieves all notifications 1 day old, 2, 2 days old etc.
    MD

    event_description <<-MD
      Here's an example of the event data that is returned by the Trello notifications agent. This is just one notification however more data will be returned based on your configuration.
    MD

    def configure
      Trello.configure do |config|
        config.developer_public_key = "4dfec6233bf4b6438e86af0ed04cccd5"
        config.member_token = "c51bf814f53953d602b613226644d50da14a5cffe1219a40afb986ff1f8e2cf7"
      end
    end

    def default_options
      {
        'public_key' => 'Public key',
        'member_token' => 'Member token',
        'board_name' => 'Name of the board'
        'username' => 'johndoe',
        'max_age' => '0',
        'expected_update_period_in_days' => '1'
      }
    end

    def validate_options
      errors.add(:base, "A public_key is required") if options['public_key'].blank?
      errors.add(:base, "A member_token is required") if options['member_token'].blank?
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      notifications = remove_old_notifications(get_notifications)
      create_event :payload => notifications
    end

    private
      def remove_old_notifications(notifications)
        if options['max_age'] == "0"
          notifications
        else
          max_age = get_max_age

          notifications.collect do |notification|
            max_age <= ActiveSupport::TimeZone[Time.zone.name].parse(notification.date)
          end
        end
      end

      def get_max_age
        max_age = options['max_age']
        if max_age.includes?('d')
          max_age[0...1].to_i.days.ago.to_i
        elsif max_age.includes?('h')
          max_age[0...1].to_i.hours.ago.to_i
        elsif max_age.includes?('m')
          max_age[0...1].to_i.minutes.ago.to_i
        end
      end

      def get_notifications
        if options['username'].present?
          notifications = get_member.notifications
          notifications = get_notifications_for_board(notifications) if options['board_name'].present?
        else
          if options['board_name'].present?
            notifications = get_board.members.collect {|member| member.notifications}
            notifications = get_notifications_for_board(notifications)
          else
            notifications = []
            get_boards.each do |board|
              board.members.each do |member|
                notifications << member.notifications
              end
            end
          end
        end
      end

      def get_notifications_for_board(notifications)
        notifications.select do |notification|
          notification.board.name == options['board_name']
        end
      end

      def get_boards
        Trello::Board.all
      end

      def get_board
        Trello::Board.all.detect {|board| board.name == options['board_name']}
      end

      def get_member(boards)
        Trello::Member.find(options['username'])
      end
  end
end
