module Agents
  class TumblrLikesAgent < Agent
    include TumblrConcern

    gem_dependency_check { defined?(Tumblr::Client) }

    description <<-MD
      The Tumblr Likes Agent checks for liked Tumblr posts from a specific blog.

      #{'## Include `tumblr_client` and `omniauth-tumblr` in your Gemfile to use this Agent!' if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Tumblr in the [Services](/services) section first.


      **Required fields:**

      `blog_name` The Tumblr URL you're querying (e.g. "staff.tumblr.com")

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    default_schedule 'every_1h'

    def validate_options
      errors.add(:base, 'blog_name is required') unless options['blog_name'].present?
      errors.add(:base, 'expected_update_period_in_days is required') unless options['expected_update_period_in_days'].present?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => '10',
        'blog_name' => 'someblog',
      }
    end

    def check
      memory[:ids] ||= []
      memory[:last_liked] ||= 0

      # Request Likes of blog_name after the last stored timestamp (or default of 0)
      liked = tumblr.blog_likes(options['blog_name'], after: memory[:last_liked])

      if liked['liked_posts']
        # Loop over all liked posts which came back from Tumblr, add to memory, and create events.
        liked['liked_posts'].each do |post|
          unless memory[:ids].include?(post['id'])
            memory[:ids].push(post['id'])
            memory[:last_liked] = post['liked_timestamp'] if post['liked_timestamp'] > memory[:last_liked]
            create_event(payload: post)
          end
        end
      elsif liked['status'] && liked['msg']
        # If there was a problem fetching likes (like 403 Forbidden or 404 Not Found) create an error message.
        error "Error finding liked posts for #{options['blog_name']}: #{liked['status']} #{liked['msg']}"
      end

      # Store only the last 50 (maximum the API will return) IDs in memory to prevent performance issues.
      memory[:ids] = memory[:ids].last(50) if memory[:ids].length > 50
    end
  end
end
