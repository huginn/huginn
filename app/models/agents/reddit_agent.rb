module Agents
  class RedditAgent < Agent
    cannot_receive_events!

  	default_schedule "every_1d"

    description <<-MD
      The Reddit Agent will scrape a subreddit frontpage for entries above an upvote treshold.
    MD

    event_description <<-MD
          {
            "title": "New Disney/Pixar Short \"Piper\"",
            "url": "https://vimeo.com/189901272",
            "comments_url": "https://www.reddit.com/r/videos/comments/5arlo9/new_disneypixar_short_piper/",
  			    "score": 6172
          }
    MD

    def default_options
      {
        'expected_update_period_in_days' => "2",
        'subreddit' => 'bitcoin',
        'minimum_score' => 40
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def validate_options
			unless %w[expected_update_period_in_days subreddit minimum_score].all? { |field| options[field].present? }
				errors.add(:base, "All fields are required")
			end
    end

    def check
      response = HTTParty.get("http://reddit.com/r/#{options['subreddit']}", headers: {"User-Agent" => "ravenflightv0.1"})
      items = extract_reddit_items(response.body)
      qualified_items = items.reject { |item| item.score < options['minimum_score'] }
      new_items = qualified_items.reject { |item| already_evented? item }
      puts new_items.map(&:title).join("\n")
			# event = {items: new_items.map(&:to_h)}
      new_items.each do |item|
        create_event :payload => item.to_h
      end
    end

    private
    def extract_reddit_items(html)
      nodes = Nokogiri.parse(html).xpath("//div[contains(@class, 'thing') and not(contains(@class, 'stickied'))]")
      nodes.map { |node| RedditItem.new(node) }
    end

    # Check if it was already reported
    def already_evented?(reddit_item)
      @previous_event_urls ||= events.pluck(:payload).map {|p| p['comments_url']}
      @previous_event_urls.include? reddit_item.comments_url
    end

    class RedditItem
      attr_reader :title, :url, :comments_url, :score

      def initialize(node)
        @title = node.xpath("descendant::p[@class='title']/a").text
        @url   = node.xpath("descendant::p[@class='title']/a/@href").text
        @comments_url = node.xpath("descendant::ul[@class = 'flat-list buttons']/li[1]/a/@href").text
        @score = node.xpath("descendant::div[@class='score unvoted']").text.to_i
      end

      def to_h
        {
          title: title,
          url: url,
          comments_url: comments_url,
          score: score
        }
      end
    end
  end
end
