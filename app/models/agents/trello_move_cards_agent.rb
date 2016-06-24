require 'trello'

module Agents
  class TrelloMoveCardsAgent < Agent
    no_bulk_receive!
    cannot_be_scheduled!
    cannot_create_events!
    gem_dependency_check { defined?(Trello) }

    description <<-MD
      The Trello Move Cards agent allows you to move card(s) from one list to another. Once the agent receives an event it will execute. The format/content of the event does not matter.

      To use the Trello Move Cards agent you will first need to sign into your Trello account.
      Once you have signed in go to the following url [https://trello.com/app-key](https://trello.com/app-key) and copy the key.
      This will be used as the agent `public_key`.

      Next on the same page click on the `Token` link and copy the token displayed. This will be used as the agent `member_token`.

      As options you must specify an `end_list_name` and a optionally a `start_list_name`. The agent will then take all the cards in the list with a name of `start_list_name` and move them into the list with a name of `end_list_name`.

      Additionally you can specify a `board_name`. If `board_name` is specified, the agent will look for `start_list_name`, `end_list_name`, and `card_name` under the specified board name. If no board name is specified, then the agent will use the first matching list or card. This would only happen if you have multiple boards with lists or cards that have the same name.

      If you don't want to move all the cards in one list to another list, you can ommit the `start_list_name` and specify a `card_name`. The agent will then search for the card and move it to the list with a name of `end_list_name`. If you specify `start_list_name` and `card_name` the agent will default to moving the single card.
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
        'start_list_name' => 'Name of list to take cards from',
        'end_list_name' => 'Name of list to move card(s) to',
        'card_name' => 'Name of card to move'
      }
    end

    def validate_options
      errors.add(:base, "A public_key is required") if options['public_key'].blank?
      errors.add(:base, "A member_token is required") if options['member_token'].blank?
      errors.add(:base, "An end_list_name is require") if options['end_list_name'].blank?
      errors.add(:base, "A start_list_name or card_name is require") if options['start_list_name'].blank? && options['card_name'].blank?
    end

    def working?
      received_event_without_error? && !recent_error_logs?
    end

    def receive(incoming_events)
      configure # is there a better way to do this?
      end_list = get_list(options['end_list_name'])

      if options['start_list_name']
        start_list = get_list(options['start_list_name'])
        start_list.move_all_cards(end_list)
      else
        card = get_card(options['card_name'])
        card.move_to_list(end_list)
      end
    end

    private
      def get_list(list_name)
        if options['board_name']
          get_board.lists.find{|list| list.name == list_name}
        else
          get_boards.each do |board|
            board.lists.find {|list| list.name == list_name}
          end
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
