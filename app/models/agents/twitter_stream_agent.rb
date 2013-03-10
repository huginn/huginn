module Agents
  class TwitterStreamAgent < Agent
    cannot_receive_events!

    description <<-MD
      The TwitterStreamAgent follows the Twitter stream in real time, watching for certain keywords, or filters, that you provide.

      You must provide a `twitter_username` and `twitter_password`, as well as an array of `filters`.  Multiple words in a filter
      must all show up in a tweet, but are independent of order.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      `generate` should be either `events` or `counts`.  If set to `counts`, it will output event summaries whenever the Agent is scheduled.
    MD

    event_description <<-MD
      When in `counts` mode, TwitterStreamAgent events look like:

          {
            :filter => "hello world",
            :count => 25,
            :time => 3456785456
          }

      When in `events` mode, TwitterStreamAgent events look like:

          { :filter=>"selectorgadget",
             ... every Tweet field, including ...
           :text=> "something",
           :user=>
            { :name=>"Mr. Someone",
              :screen_name=>"Someone",
              :location=>"Vancouver BC Canada",
              :description=> "...",
              :followers_count=>486,
              :friends_count=>1983,
              :created_at=>"Mon Aug 29 23:38:14 +0000 2011",
              :time_zone=>"Pacific Time (US & Canada)",
              :statuses_count=>3807,
              :lang=>"en" },
           :retweet_count=>0,
           :entities=> ...
           :lang=>"en" }
    MD

    default_schedule "11pm"

    def validate_options
      unless options[:twitter_username].present? && options[:twitter_password].present? && options[:filters].present? && options[:expected_update_period_in_days].present? && options[:generate].present?
        errors.add(:base, "expected_update_period_in_days, generate, twitter_username, twitter_password, and filters are required")
      end
    end

    def working?
      (event = event_created_within(options[:expected_update_period_in_days].to_i.days)) && event.payload.present?
    end

    def default_options
      {
          :twitter_username => "---",
          :twitter_password => "---",
          :filters => %w[keyword1 keyword2],
          :expected_update_period_in_days => "2",
          :generate => "events"
      }
    end

    def process_tweet(filter, status)
      if options[:generate] == "counts"
        # Avoid memory pollution
        me = Agent.find(id)
        me.memory[:filter_counts] ||= {}
        me.memory[:filter_counts][filter.to_sym] ||= 0
        me.memory[:filter_counts][filter.to_sym] += 1
        me.save!
      else
        create_event :payload => status.merge(:filter => filter.to_s)
      end
    end

    def check
      if memory[:filter_counts] && memory[:filter_counts].length > 0
        memory[:filter_counts].each do |filter, count|
          create_event :payload => { :filter => filter.to_s, :count => count, :time => Time.now.to_i }
        end
        memory[:filter_counts] = {}
        save!
      end
    end
  end
end