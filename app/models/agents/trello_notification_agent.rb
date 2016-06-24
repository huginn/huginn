require 'trello'

module Agents
  class TrelloNotificationAgent < Agent
    no_bulk_receive!
    default_schedule "every_1h"
    cannot_receive_events!
    gem_dependency_check { defined?(Trello) }

    description <<-MD
      The Trello Notification agent allows you to get notifications from your Trello account.

      To use the Trello Notification agent you will first need to sign into your Trello account.
      Once you have signed in go to the following url [https://trello.com/app-key](https://trello.com/app-key) and copy the key.
      This will be used as the agent `public_key`.

      Next on the same page click on the `Token` link and copy the token displayed. This will be used as the agent `member_token`.

      Additionally you can specify the Trello board name with the `board_name` option. This will restrict the agent to notifications of that particular board. If no board is specified, then notifications from all boards is returned.

      You will also need to specify you Trello username as `username`. If no username is specified it will get a list of notifications for all members of the specified board.

      Finally you will also need to specify the max age of the notifications to retrieve with the `max_age` option. By default this is 0 which will retrieve all notifications. 1d retrieves all notifications 1 day old, 2d - 2 days old, 1h - 1 hour old, 1m - 1 minute old etc.
    MD

    event_description <<-MD
      Here's an example of the event data that is returned by the Trello notifications agent. This is just one notification however more data could be returned based on your configuration. Different types of data can also be returned depending on the type of notification.

          {
            "notifications":
            {
              "id": "1119afa1ggg775cg2fmom9a0",
              "unread": false,
              "type": "commentCard",
              "date": "2016-06-17T08:06:57.843Z",
              "data": {
                "text": "@user ready for testing.",
                "card": {
                  "shortLink": "bC78glii",
                  "idShort": 200,
                  "name": "As a user, when I'm on the Edit Profile Page, if I edit the form and hit save, it should close the form.",
                  "id": "573c735c13dcb2411a32d6bd"
                },
                "board": {
                  "shortLink": "H1RadcyM",
                  "name": "Software App",
                  "id": "54b573g3454906237bc9cb70"
                }
              },
              "member_creator_id": "4eg0df123bf061922g054540"
            }
          }
    MD

    def configure
      Trello.configure do |config|
        config.developer_public_key = options['public_key']
        config.member_token = options['member_token']
      end
    end

    def default_options
      {
        'public_key' => 'Public key',
        'member_token' => 'Member token',
        'board_name' => 'Name of the board',
        'username' => 'johndoe',
        'max_age' => '0',
        'expected_update_period_in_days' => '1',
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
      configure # is there a better way to do this?
      notifications = remove_old_notifications(get_notifications)
      create_event :payload => {notifications: notifications}
    end

    private
      def remove_old_notifications(notifications)
        notifications_array = []

        if options['max_age'] == "0"
          notifications.each do |notification|
            notifications_array << notification.attributes
          end
        else
          max_age = get_max_age

          notifications.each do |notification|
            if max_age <= ActiveSupport::TimeZone[Time.zone.name].parse(notification.date).to_i
              notifications_array << notification.attributes
            end
          end
        end

        notifications_array
      end

      def get_max_age
        max_age = options['max_age']
        if max_age.include?('d')
          max_age[0...1].to_i.days.ago.to_i
        elsif max_age.include?('h')
          max_age[0...1].to_i.hours.ago.to_i
        elsif max_age.include?('m')
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
        Trello::Action.search(
          options['board_name'],
          modelTypes: "boards",
          board_fields: "name"
        )['boards'].first
      end

      def get_member
        Trello::Member.find(options['username'])
      end
  end
end
