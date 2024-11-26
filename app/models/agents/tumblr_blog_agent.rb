module Agents
  class TumblrBlogAgent < Agent
    include TumblrConcern

    cannot_receive_events!

    description <<-MD
      #{tumblr_dependencies_missing if dependencies_missing?}
      The TumblrUserAgent follows the timeline of a specified Tumblr blog.

      To be able to use this Agent you need to authenticate with Tumblr in the [Services](/services) section first.

      You must also provide the `blog_name` of the Tumblr blog to monitor.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Set `tag` to filter blog posts to those with the specified tag.

    MD

    event_description <<-MD
      Events are the raw JSON provided by the [Tumblr API](https://www.tumblr.com/docs/en/api/v2#posts). Should look something like:

          {
            "blog_name": "mustardhamsters",
            "id": 98271204078,
            "post_url": "http://mustardhamsters.tumblr.com/post/98271204078/steven-universe-is-under-pressure",
            "slug": "steven-universe-is-under-pressure",
            "type": "photo",
            "date": "2014-09-24 01:23:01 GMT",
            "timestamp": 1411521781,
            "state": "published",
            "format": "html",
            "reblog_key": "stSGhPNG",
            "tags": [
              "gif",
              "steven universe"
            ],
            "short_url": "http://tmblr.co/Zz_TXy1RXQvBk",
            "followed": false,
            "highlighted": [],
            "liked": false,
            "note_count": 127,
            "caption": "<p>Steven Universe is under pressure.<\/p>",
            "image_permalink": "http://mustardhamsters.tumblr.com/image/98271204078",
            "photos": [
              {
                "caption": "",
                "alt_sizes": [
                  {
                    "width": 500,
                    "height": 281,
                    "url": "http://38.media.tumblr.com/670dc67eedb81e231e48008c37884417/tumblr_ncdt6dHY8O1qzgw0so1_500.gif"
                  },
                  Etc...
                ],
                "original_size": {
                  "width": 500,
                  "height": 281,
                  "url": "http://38.media.tumblr.com/670dc67eedb81e231e48008c37884417/tumblr_ncdt6dHY8O1qzgw0so1_500.gif"
                }
              }
            ],
            "can_reply": false
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
