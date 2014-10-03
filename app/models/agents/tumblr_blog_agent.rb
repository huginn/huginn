module Agents
  class TumblrBlogAgent < Agent
    include TumblrConcern

    cannot_receive_events!

    description <<-MD
      #{tumblr_dependencies_missing if dependencies_missing?}
      The TumblrUserAgent follows the timeline of a specified Tumblr user.

      To be able to use this Agent you need to authenticate with Tumblr in the [Services](/services) section first.

      You must also provide the `blog_name` of the Tumblr blog to monitor.

      Set `include_reblogs` to `false` to not include reblogs (default: `true`)

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Set `starting_at` to the date/time (eg. `Mon Jun 02 00:38:12 +0000 2014`) you want to start receiving posts from (default: agent's `created_at`)
    MD

    event_description <<-MD
      Events are the raw JSON provided by the [Tumblr API](https://dev.tumblr.com/docs/api/1.1/get/statuses/user_timeline). Should look something like:

          {
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
            "repost_count": 0,
            "entities": ...
            "lang": "en"
          }
    MD

    default_schedule "every_1h"

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'blog_name' => 'mustardhamsters.tumblr.com',
        'expected_update_period_in_days' => '2',
        'tag' => '',
      }
    end

    def validate_options
      errors.add(:base, "blog_name is required") unless options['blog_name'].present?
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
    end



    def check
      if interpolated['tag']
        posts = tumblr.posts(interpolated['blog_name'], :tag => interpolated['tag'])
      else
        posts = tumblr.posts(interpolated['blog_name'])
      end

      posts["posts"].reverse_each do |post|
        if !memory['since_id'] || (post["id"] > memory['since_id'])
          create_event :payload => post
          memory['since_id'] = post["id"]
        end
      end

      save!
    end
  end
end
