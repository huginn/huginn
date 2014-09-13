require 'rss'
require 'feed-normalizer'

module Agents
  class RssAgent < Agent
    include WebRequestConcern

    cannot_receive_events!
    default_schedule "every_1d"

    description do
      <<-MD
        This Agent consumes RSS feeds and emits events when they change.

        (If you want to *output* an RSS feed, use the DataOutputAgent.  Also, you can technically parse RSS and XML feeds
        with the WebsiteAgent as well.  See [this example](https://github.com/cantino/huginn/wiki/Agent-configuration-examples#itunes-trailers).)

        Options:

          * `url` - The URL of the RSS feed.
          * `clean` - Attempt to use [feed-normalizer](https://github.com/aasmith/feed-normalizer)'s' `clean!` method to cleanup HTML in the feed.  Set to `true` to use.
          * `expected_update_period_in_days` - How often you expect this RSS feed to change.  If more than this amount of time passes without an update, the Agent will mark itself as not working.
          * `headers` - When present, it should be a hash of headers to send with the request.
          * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
          * `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").
      MD
    end

    def default_options
      {
        'expected_update_period_in_days' => "5",
        'clean' => 'false',
        'url' => "https://github.com/cantino/huginn/commits/master.atom"
      }
    end

    event_description <<-MD
      Events look like:

          {
            "id": "829f845279611d7925146725317b868d",
            "date_published": "2014-09-11 01:30:00 -0700",
            "last_updated": "Thu, 11 Sep 2014 01:30:00 -0700",
            "urls": [ "http://example.com/..." ],
            "description": "Some description",
            "content": "Some content",
            "title": "Some title",
            "authors": [ ... ],
            "categories": [ ... ]
          }

    MD

    def working?
      event_created_within?((interpolated['expected_update_period_in_days'].presence || 10).to_i) && !recent_error_logs?
    end

    def validate_options
      errors.add(:base, "url is required") unless options['url'].present?

      unless options['expected_update_period_in_days'].present? && options['expected_update_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_update_period_in_days' to indicate how many days can pass without an update before this Agent is considered to not be working")
      end

      validate_web_request_options!
    end

    def check
      response = faraday.get(interpolated['url'])
      if response.success?
        feed = FeedNormalizer::FeedNormalizer.parse(response.body)
        feed.clean! if interpolated['clean'] == 'true'
        created_event_count = 0
        feed.entries.each do |entry|
          entry_id = get_entry_id(entry)
          if check_and_track(entry_id)
            created_event_count += 1
            create_event(:payload => {
              :id => entry_id,
              :date_published => entry.date_published,
              :last_updated => entry.last_updated,
              :urls => entry.urls,
              :description => entry.description,
              :content => entry.content,
              :title => entry.title,
              :authors => entry.authors,
              :categories => entry.categories
            })
          end
        end
        log "Fetched #{interpolated['url']} and created #{created_event_count} event(s)."
      else
        error "Failed to fetch #{interpolated['url']}: #{response.inspect}"
      end
    end

    protected

    def get_entry_id(entry)
      entry.id.presence || Digest::MD5.hexdigest(entry.content)
    end

    def check_and_track(entry_id)
      memory['seen_ids'] ||= []
      if memory['seen_ids'].include?(entry_id)
        false
      else
        memory['seen_ids'].unshift entry_id
        memory['seen_ids'].pop if memory['seen_ids'].length > 500
        true
      end
    end
  end
end
