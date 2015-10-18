module Agents
  class PocketRetrieve < Agent
    include PocketConcern

    cannot_receive_events!

    description <<-MD
      Pocket Agent retrieving Items
    MD
    event_description <<-MD
      Description...
    MD

    default_schedule "every_1h"

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'number' => '10',
        'history' => '100',
        'expected_update_period_in_days' => '2'
      }
    end

     def validate_options
      errors.add(:base, "number is required") unless options['number'].present?
      errors.add(:base, "history is required") unless options['number'].present?
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
    end
### start here ###
    def check
      opts = {:count => interpolated['number']}
      tweets = twitter.favorites(interpolated['username'], opts)

      tweets.each do |tweet|
        if memory[:last_seen].nil? 
          memory[:last_seen] = Array.new()
        else
          if memory[:last_seen].include? tweet.id
          else
            memory[:last_seen].push(tweet.id)
            create_event :payload => tweet.attrs
          end
        end
      end
      
      if memory[:last_seen].length > interpolated['history'].to_i
        memory[:last_seen] = memory[:last_seen][0,interpolated['history'].to_i/2]
      end
      save!
    end
  end
end
