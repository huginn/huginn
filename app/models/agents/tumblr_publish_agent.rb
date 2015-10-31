require "tumblr_client"

module Agents
  class TumblrPublishAgent < Agent
    include TumblrConcern

    cannot_be_scheduled!

    description <<-MD
      The Tumblr Publish Agent publishes Tumblr posts from the events it receives.

      #{'## Include `tumblr_client` and `omniauth-tumblr` in your Gemfile to use this Agent!' if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Tumblr in the [Services](/services) section first.



      **Required fields:**

      `blog_name` Your Tumblr URL (e.g. "mustardhamsters.tumblr.com")

      `post_type` One of [text, photo, quote, link, chat, audio, video, reblog]


      -------------

      You may leave any of the following optional fields blank. Including a field not allowed for the specified `post_type` will cause a failure.

      **Any post type**

      * `state` published, draft, queue, private
      * `tags` Comma-separated tags for this post
      * `tweet` off, text for tweet
      * `date` GMT date and time of the post as a string
      * `format` html, markdown
      * `slug` short text summary at end of the post URL

      **Text** `title` `body`

      **Photo** `caption` `link`  `source`

      **Quote** `quote` `source`

      **Link** `title` `url` `description`

      **Chat** `title` `conversation`

      **Audio** `caption` `external_url`

      **Video** `caption` `embed`

      **Reblog** `id` `reblog_key` `comment`

      -------------

      [Full information on field options](https://www.tumblr.com/docs/en/api/v2#posting)

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    gem_dependency_check { defined?(Tumblr) }

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => "10",
        'blog_name' => "{{blog_name}}",
        'post_type' => "{{post_type}}",
        'options' => {
          'state' => "{{state}}",
          'tags' => "{{tags}}",
          'tweet' => "{{tweet}}",
          'date' => "{{date}}",
          'format' => "{{format}}",
          'slug' => "{{slug}}",
          'title' => "{{title}}",
          'body' => "{{body}}",
          'caption' => "{{caption}}",
          'link' => "{{link}}",
          'source' => "{{source}}",
          'quote' => "{{quote}}",
          'url' => "{{url}}",
          'description' => "{{description}}",
          'conversation' => "{{conversation}}",
          'external_url' => "{{external_url}}",
          'embed' => "{{embed}}",
          'id' => "{{id}}",
          'reblog_key' => "{{reblog_key}}",
          'comment' => "{{comment}}",
        },
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 20
        incoming_events = incoming_events.first(20)
      end
      incoming_events.each do |event|
        blog_name = interpolated(event)['blog_name']
        post_type = interpolated(event)['post_type']
        options = interpolated(event)['options']
        begin
          post = publish_post(blog_name, post_type, options)
          if !post.has_key?('id')
            log("Failed to create #{post_type} post on #{blog_name}: #{post.to_json}, options: #{options.to_json}")
            return
          end
          expanded_post = get_post(blog_name, post["id"])
          create_event :payload => {
            'success' => true,
            'published_post' => "["+blog_name+"] "+post_type,
            'post_id' => post["id"],
            'agent_id' => event.agent_id,
            'event_id' => event.id,
            'post' => expanded_post
          }
        end
      end
    end

    def publish_post(blog_name, post_type, options)
      options_obj = {
          :state => options['state'],
          :tags => options['tags'],
          :tweet => options['tweet'],
          :date => options['date'],
          :format => options['format'],
          :slug => options['slug'],
        }

      case post_type
      when "text"
        options_obj[:title] = options['title']
        options_obj[:body] = options['body']
        tumblr.text(blog_name, options_obj)
      when "photo"
        options_obj[:caption] = options['caption']
        options_obj[:link] = options['link']
        options_obj[:source] = options['source']
        tumblr.photo(blog_name, options_obj)
      when "quote"
        options_obj[:quote] = options['quote']
        options_obj[:source] = options['source']
        tumblr.quote(blog_name, options_obj)
      when "link"
        options_obj[:title] = options['title']
        options_obj[:url] = options['url']
        options_obj[:description] = options['description']
        tumblr.link(blog_name, options_obj)
      when "chat"
        options_obj[:title] = options['title']
        options_obj[:conversation] = options['conversation']
        tumblr.chat(blog_name, options_obj)
      when "audio"
        options_obj[:caption] = options['caption']
        options_obj[:external_url] = options['external_url']
        tumblr.audio(blog_name, options_obj)
      when "video"
        options_obj[:caption] = options['caption']
        options_obj[:embed] = options['embed']
        tumblr.video(blog_name, options_obj)
      when "reblog"
        options_obj[:id] = options['id']
        options_obj[:reblog_key] = options['reblog_key']
        options_obj[:comment] = options['comment']
        tumblr.reblog(blog_name, options_obj)
      end
    end

    def get_post(blog_name, id)
      obj = tumblr.posts(blog_name, {
        :id => id
      })
      obj["posts"].first
    end
  end
end
