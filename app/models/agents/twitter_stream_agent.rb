module Agents
  class TwitterStreamAgent < Agent
    include TwitterConcern
    include LongRunnable

    cannot_receive_events!

    description <<-MD
      The Twitter Stream Agent follows the Twitter stream in real time, watching for certain keywords, or filters, that you provide.

      #{twitter_dependencies_missing if dependencies_missing?}

      To follow the Twitter stream, provide an array of `filters`.  Multiple words in a filter must all show up in a tweet, but are independent of order.
      If you provide an array instead of a filter, the first entry will be considered primary and any additional values will be treated as aliases.

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      `generate` should be either `events` or `counts`.  If set to `counts`, it will output event summaries whenever the Agent is scheduled.
    MD

    event_description <<-MD
      When in `counts` mode, TwitterStreamAgent events look like:

          {
            "filter": "hello world",
            "count": 25,
            "time": 3456785456
          }

      When in `events` mode, TwitterStreamAgent events look like:

          {
            "filter": "selectorgadget",
             ... every Tweet field, including ...
            "text": "something",
            "user": {
              "name": "Mr. Someone",
              "screen_name": "Someone",
              "location": "Vancouver BC Canada",
              "description":  "...",
              "followers_count": 486,
              "friends_count": 1983,
              "created_at": "Mon Aug 29 23:38:14 +0000 2011",
              "time_zone": "Pacific Time (US & Canada)",
              "statuses_count": 3807,
              "lang": "en"
            },
            "retweet_count": 0,
            "entities": ...
            "lang": "en"
          }
    MD

    default_schedule "11pm"

    def validate_options
      unless options['filters'].present? &&
             options['expected_update_period_in_days'].present? &&
             options['generate'].present?
        errors.add(:base, "expected_update_period_in_days, generate, and filters are required fields")
      end
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'filters' => %w[keyword1 keyword2],
        'expected_update_period_in_days' => "2",
        'generate' => "events"
      }
    end

    def process_tweet(filter, status)
      filter = lookup_filter(filter)

      if filter
        if interpolated['generate'] == "counts"
          # Avoid memory pollution by reloading the Agent.
          agent = Agent.find(id)
          agent.memory['filter_counts'] ||= {}
          agent.memory['filter_counts'][filter] ||= 0
          agent.memory['filter_counts'][filter] += 1
          remove_unused_keys!(agent, 'filter_counts')
          agent.save!
        else
          create_event :payload => status.merge('filter' => filter)
        end
      end
    end

    def check
      if interpolated['generate'] == "counts" && memory['filter_counts'] && memory['filter_counts'].length > 0
        memory['filter_counts'].each do |filter, count|
          create_event :payload => { 'filter' => filter, 'count' => count, 'time' => Time.now.to_i }
        end
      end
      memory['filter_counts'] = {}
    end

    protected

    def lookup_filter(filter)
      interpolated['filters'].each do |known_filter|
        if known_filter == filter
          return filter
        elsif known_filter.is_a?(Array)
          if known_filter.include?(filter)
            return known_filter.first
          end
        end
      end
    end

    def remove_unused_keys!(agent, base)
      if agent.memory[base]
        (agent.memory[base].keys - agent.interpolated['filters'].map {|f| f.is_a?(Array) ? f.first.to_s : f.to_s }).each do |removed_key|
          agent.memory[base].delete(removed_key)
        end
      end
    end

    def self.setup_worker
      Agents::TwitterStreamAgent.active.order(:id).group_by { |agent| agent.twitter_oauth_token }.map do |oauth_token, agents|
        if Agents::TwitterStreamAgent.dependencies_missing?
          STDERR.puts Agents::TwitterStreamAgent.twitter_dependencies_missing
          STDERR.flush
          return false
        end

        filter_to_agent_map = agents.map { |agent| agent.options[:filters] }.flatten.uniq.compact.map(&:strip).inject({}) { |m, f| m[f] = []; m }

        agents.each do |agent|
          agent.options[:filters].flatten.uniq.compact.map(&:strip).each do |filter|
            filter_to_agent_map[filter] << agent
          end
        end

        config_hash = filter_to_agent_map.map { |k, v| [k, v.map(&:id)] }
        config_hash.push(oauth_token)

        Worker.new(id: agents.first.worker_id(config_hash),
                   config: {filter_to_agent_map: filter_to_agent_map},
                   agent: agents.first)
      end
    end

    class Worker < LongRunnable::Worker
      RELOAD_TIMEOUT = 60.minutes
      DUPLICATE_DETECTION_LENGTH = 1000
      SEPARATOR = /[^\w_\-]+/

      def setup
        require 'twitter/json_stream'
        @filter_to_agent_map = @config[:filter_to_agent_map]
      end

      def run
        @recent_tweets = []
        EventMachine.run do
          EventMachine.add_periodic_timer(RELOAD_TIMEOUT) do
            restart!
          end
          stream!(@filter_to_agent_map.keys, @agent) do |status|
            handle_status(status)
          end
        end
        Thread.stop
      end

      def stop
        EventMachine.stop_event_loop if EventMachine.reactor_running?
        terminate_thread!
      end

      private
      def stream!(filters, agent, &block)
        filters = filters.map(&:downcase).uniq

        stream = Twitter::JSONStream.connect(
          :path    => "/1.1/statuses/#{(filters && filters.length > 0) ? 'filter' : 'sample'}.json#{"?track=#{filters.map {|f| CGI::escape(f) }.join(",")}" if filters && filters.length > 0}",
          :ssl     => true,
          :oauth   => {
            :consumer_key    => agent.twitter_consumer_key,
            :consumer_secret => agent.twitter_consumer_secret,
            :access_key      => agent.twitter_oauth_token,
            :access_secret   => agent.twitter_oauth_token_secret
          }
        )

        stream.each_item do |status|
          block.call(status)
        end

        stream.on_error do |message|
          STDERR.puts " --> Twitter error: #{message} at #{Time.now} <--"
          STDERR.puts " --> Sleeping for 15 seconds"
          sleep 15
          restart!
        end

        stream.on_no_data do |message|
          STDERR.puts " --> Got no data for awhile; trying to reconnect at #{Time.now} <--"
          restart!
        end

        stream.on_max_reconnects do |timeout, retries|
          STDERR.puts " --> Oops, tried too many times! at #{Time.now} <--"
          sleep 60
          restart!
        end
      end

      def handle_status(status)
        status = JSON.parse(status) if status.is_a?(String)
        return unless status
        return if status.has_key?('delete')
        return unless status['text']
        status['text'] = status['text'].gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/[\t\n\r]/, '  ')

        if status["retweeted_status"].present? && status["retweeted_status"].is_a?(Hash)
          return
        elsif @recent_tweets.include?(status["id_str"])
          puts "(#{Time.now}) Skipping duplicate tweet: #{status["text"]}"
          return
        end

        @recent_tweets << status["id_str"]
        @recent_tweets.shift if @recent_tweets.length > DUPLICATE_DETECTION_LENGTH
        @filter_to_agent_map.keys.each do |filter|
          next unless (filter.downcase.split(SEPARATOR) - status["text"].downcase.split(SEPARATOR)).reject(&:empty?) == [] # Hacky McHackerson
          @filter_to_agent_map[filter].each do |agent|
            puts "(#{Time.now}) #{agent.name} received: #{status["text"]}"
            AgentRunner.with_connection do
              agent.process_tweet(filter, status)
            end
          end
        end
      end
    end
  end
end
