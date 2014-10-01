require 'cgi'
require 'json'
require 'em-http-request'
require 'pp'

class TwitterStream
  def initialize
    @running = true
  end

  def stop
    @running = false
  end

  def stream!(filters, agent, &block)
    stream = Twitter::JSONStream.connect(
      :path    => "/1/statuses/#{(filters && filters.length > 0) ? 'filter' : 'sample'}.json#{"?track=#{filters.map {|f| CGI::escape(f) }.join(",")}" if filters && filters.length > 0}",
      :ssl     => true,
      :oauth   => {
        :consumer_key    => agent.twitter_consumer_key,
        :consumer_secret => agent.twitter_consumer_secret,
        :access_key      => agent.twitter_oauth_token,
        :access_secret   => agent.twitter_oauth_token_secret
      }
    )

    stream.each_item do |status|
      status = JSON.parse(status) if status.is_a?(String)
      next unless status
      next if status.has_key?('delete')
      next unless status['text']
      status['text'] = status['text'].gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/[\t\n\r]/, '  ')
      block.call(status)
    end

    stream.on_error do |message|
      STDERR.puts " --> Twitter error: #{message} <--"
    end

    stream.on_no_data do |message|
      STDERR.puts " --> Got no data for awhile; trying to reconnect."
      EventMachine::stop_event_loop
    end

    stream.on_max_reconnects do |timeout, retries|
      STDERR.puts " --> Oops, tried too many times! <--"
      EventMachine::stop_event_loop
    end
  end

  def load_and_run(agents)
    agents.group_by { |agent| agent.twitter_oauth_token }.each do |oauth_token, agents|
      filter_to_agent_map = agents.map { |agent| agent.options[:filters] }.flatten.uniq.compact.map(&:strip).inject({}) { |m, f| m[f] = []; m }

      agents.each do |agent|
        agent.options[:filters].flatten.uniq.compact.map(&:strip).each do |filter|
          filter_to_agent_map[filter] << agent
        end
      end

      recent_tweets = []

      stream!(filter_to_agent_map.keys, agents.first) do |status|
        if status["retweeted_status"].present? && status["retweeted_status"].is_a?(Hash)
          puts "Skipping retweet: #{status["text"]}"
        elsif recent_tweets.include?(status["id_str"])
          puts "Skipping duplicate tweet: #{status["text"]}"
        else
          recent_tweets << status["id_str"]
          recent_tweets.shift if recent_tweets.length > DUPLICATE_DETECTION_LENGTH
          puts status["text"]
          filter_to_agent_map.keys.each do |filter|
            if (filter.downcase.split(SEPARATOR) - status["text"].downcase.split(SEPARATOR)).reject(&:empty?) == [] # Hacky McHackerson
              filter_to_agent_map[filter].each do |agent|
                puts " -> #{agent.name}"
                agent.process_tweet(filter, status)
              end
            end
          end
        end
      end
    end
  end

  RELOAD_TIMEOUT = 10.minutes
  DUPLICATE_DETECTION_LENGTH = 1000
  SEPARATOR = /[^\w_\-]+/

  def run
    if Agents::TwitterStreamAgent.dependencies_missing?
      STDERR.puts Agents::TwitterStreamAgent.twitter_dependencies_missing
      STDERR.flush
      return
    end

    require 'twitter/json_stream'

    while @running
      begin
        agents = Agents::TwitterStreamAgent.active.all

        EventMachine::run do
          EventMachine.add_periodic_timer(1) {
            EventMachine::stop_event_loop if !@running
          }

          EventMachine.add_periodic_timer(RELOAD_TIMEOUT) {
            puts "Reloading EventMachine and all Agents..."
            EventMachine::stop_event_loop
          }

          if agents.length == 0
            puts "No agents found.  Will look again in a minute."
            EventMachine.add_timer(60) {
              EventMachine::stop_event_loop
            }
          else
            puts "Found #{agents.length} agent(s).  Loading them now..."
            load_and_run agents
          end
        end
      rescue SignalException, SystemExit
        @running = false
        EventMachine::stop_event_loop if EventMachine.reactor_running?
      rescue StandardError => e
        STDERR.puts "\nException #{e.message}:\n#{e.backtrace.join("\n")}\n\n"
        STDERR.puts "Waiting for a couple of minutes..."
        sleep 120
      end
    end
  end
end