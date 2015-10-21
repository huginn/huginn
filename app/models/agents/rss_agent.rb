require 'rss'
require 'feed-normalizer'

module Agents
  class RssAgent < Agent
    include WebRequestConcern

    cannot_receive_events!
    can_dry_run!
    default_schedule "every_1d"

    DEFAULT_EVENTS_ORDER = [['{{date_published}}', 'time'], ['{{last_updated}}', 'time']]

    description do
      <<-MD
        The RSS Agent consumes RSS feeds and emits events when they change.

        This Agent is fairly simple, using [feed-normalizer](https://github.com/aasmith/feed-normalizer) as a base.  For complex feeds
        with additional field types, we recommend using a WebsiteAgent.  See [this example](https://github.com/cantino/huginn/wiki/Agent-configuration-examples#itunes-trailers).

        If you want to *output* an RSS feed, use the DataOutputAgent.

        Options:

          * `url` - The URL of the RSS feed (an array of URLs can also be used; items with identical guids across feeds will be considered duplicates).
          * `clean` - Attempt to use [feed-normalizer](https://github.com/aasmith/feed-normalizer)'s' `clean!` method to cleanup HTML in the feed.  Set to `true` to use.
          * `expected_update_period_in_days` - How often you expect this RSS feed to change.  If more than this amount of time passes without an update, the Agent will mark itself as not working.
          * `headers` - When present, it should be a hash of headers to send with the request.
          * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
          * `disable_ssl_verification` - Set to `true` to disable ssl verification.
          * `disable_url_encoding` - Set to `true` to disable url encoding.
          * `force_encoding` - Set `force_encoding` to an encoding name if the website is known to respond with a missing, invalid or wrong charset in the Content-Type header.  Note that a text content without a charset is taken as encoded in UTF-8 (not ISO-8859-1).
          * `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").
          * `max_events_per_run` - Limit number of events created (items parsed) per run for feed.

        # Ordering Events

        #{description_events_order}

        In this Agent, the default value for `events_order` is `#{DEFAULT_EVENTS_ORDER.to_json}`.
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
            "url": "http://example.com/...",
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
      validate_events_order
    end

    def events_order
      super.presence || DEFAULT_EVENTS_ORDER
    end

    def check
      check_urls(Array(interpolated['url']))
    end

    protected

    def check_urls(urls)
      new_events = []
      max_events = (interpolated['max_events_per_run'].presence || 0).to_i

      urls.each do |url|
        begin
          response = faraday.get(url)
          if response.success?
            feed = FeedNormalizer::FeedNormalizer.parse(response.body, loose: true)
            feed.clean! if boolify(interpolated['clean'])
            new_events.concat feed_to_events(feed)
          else
            error "Failed to fetch #{url}: #{response.inspect}"
          end
        rescue => e
          error "Failed to fetch #{url} with message '#{e.message}': #{e.backtrace}"
        end
      end

      created_event_count = 0
      sort_events(new_events).each.with_index do |event, index|
        entry_id = event.payload[:id]
        if check_and_track(entry_id)
          unless max_events && max_events > 0 && index >= max_events
            created_event_count += 1
            create_event(event)
          end
        end
      end
      log "Fetched #{urls.to_sentence} and created #{created_event_count} event(s)."
    end

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

    def feed_to_events(feed)
      feed.entries.map { |entry|
        Event.new(payload: {
                    id: get_entry_id(entry),
                    date_published: entry.date_published,
                    last_updated: entry.last_updated,
                    url: entry.url,
                    urls: entry.urls,
                    description: entry.description,
                    content: entry.content,
                    title: entry.title,
                    authors: entry.authors,
                    categories: entry.categories
                  })
      }
    end
  end
end
