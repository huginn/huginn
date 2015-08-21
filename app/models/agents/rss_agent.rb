require 'rss'

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

        For complex feeds with additional field types, we recommend using a WebsiteAgent.  See [this example](https://github.com/cantino/huginn/wiki/Agent-configuration-examples#itunes-trailers).

        If you want to *output* an RSS feed, use the DataOutputAgent.

        Options:

          * `url` - The URL of the RSS feed (an array of URLs can also be used; items with identical guids across feeds will be considered duplicates).
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
        'url' => "https://github.com/cantino/huginn/commits/master.atom"
      }
    end

    event_description <<-MD
      Events look like:

          {
            "feed": {
              "type": "atom",
              "generator": "...",
              "title": "Some site title",
              "urls": ["http://example.com/"],
              "url": "http://example.com/",
              "description": "Some site description",
              "copyright": "...",
              "authors": [ ... ],
              "last_updated": "Thu, 11 Sep 2014 01:30:00 -0700",
              "id": "...",
              "icon": "http://example.com/icon.png"
            },
            "id": "829f845279611d7925146725317b868d",
            "date_published": "2014-09-11 01:30:00 -0700",
            "last_updated": "Thu, 11 Sep 2014 01:30:00 -0700",
            "links": [
              { "href": "http://example.com/", "rel": "alternate", "type": "text/html" },
              { "href": "http://example.com/index.atom", "rel": "self", "type": "application/atom+xml" }
            ],
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
      Array(interpolated['url']).each do |url|
        check_url(url)
      end
    end

    protected

    def check_url(url)
      response = faraday.get(url)
      if response.success?
        feed =
          begin
            RSS::Parser.parse(response.body)
          rescue RSS::InvalidRSSError
            RSS::Parser.parse(response.body, false)
          end
        max_events = (interpolated['max_events_per_run'].presence || 0).to_i
        created_event_count = 0
        sort_events(feed_to_events(feed)).each.with_index do |event, index|
          break if max_events && max_events > 0 && index >= max_events
          entry_id = event.payload[:id]
          if check_and_track(entry_id)
            created_event_count += 1
            create_event(event)
          end
        end
        log "Fetched #{url} and created #{created_event_count} event(s)."
      else
        error "Failed to fetch #{url}: #{response.inspect}"
      end
    rescue => e
      error "Failed to fetch #{url} with message '#{e.message}': #{e.backtrace}"
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

    def feed_data(feed)
      case type = feed.feed_type
      when 'rss'.freeze
        channel = feed.channel
        url = channel.link
        {
          type: type,
          generator: channel.generator,
          title: channel.title,
          urls: Array(url),
          url: url,
          description: channel.description,
          copyright: channel.copyright,
          authors: Array(channel.managingEditor),
          last_updated: channel.lastBuildDate || channel.pubDate || channel.dc_date,
          id: channel.try(:guid),
          icon: channel.image.try(:url),
        }
      when 'atom'.freeze
        urls = feed.links.map(&:href)
        {
          type: type,
          generator: feed.generator.try(:content),
          title: feed.title.try(:content),
          links: feed.links.map { |link| link_to_hash(link) },
          urls: urls,
          url: urls.first,
          description: feed.subtitle.try(:content),
          copyright: feed.rights.try(:first).try(:content),
          authors: feed.authors.map { |author| author.name.try(:content) }.compact,
          last_updated: feed.updated.try(:content),
          id: feed.id.try(:content),
          icon: feed.icon.try(:content),
        }
      end
    end

    def link_to_hash(link)
      %i[href rel type hreflang title length].each_with_object({}) { |attr, hash|
        hash[attr] = link.__send__(attr)
      }
    end

    def entry_data(entry)
      case entry
      when RSS::Rss::Channel::Item
        url = entry.link
        description = entry.description
        content = entry.content_encoded || description
        date_published = entry.pubDate || entry.dc_date
        id = entry.try(:guid).try(:content) || Digest::MD5.hexdigest(content || '')
        authors = [entry.dc_creator, entry.author].compact
        categories = entry.categories.map(&:content)
        {
          id: id,
          date_published: date_published,
          last_updated: date_published,
          url: url,
          urls: Array(url),
          description: description,
          content: content,
          title: entry.title,
          authors: authors,
          categories: categories,
        }
      when RSS::Atom::Feed::Entry
        url = entry.link.try(:href)
        summary = entry.summary.try(:content)
        content = entry.content.try(:content) || summary
        description = summary || content
        date_published = entry.published.try(:content)
        id = entry.id.try(:content) || Digest::MD5.hexdigest(content || '')
        categories = entry.categories.map(&:content)
        {
          id: id,
          date_published: date_published,
          last_updated: entry.updated.try(:content) || date_published,
          links: entry.links.map { |link| link_to_hash(link) },
          url: url,
          urls: Array(url),
          description: description,
          content: content,
          title: entry.title.try(:content),
          authors: entry.authors.map { |author| author.name.try(:content) }.compact,
          categories: categories,
        }
      end
    end

    def feed_to_events(feed)
      payload_base = {
        feed: feed_data(feed)
      }

      feed.items.map { |entry|
        Event.new(payload: payload_base.merge(entry_data(entry)))
      }
    end
  end
end
