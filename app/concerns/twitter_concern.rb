module TwitterConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_twitter_options
    valid_oauth_providers :twitter

    gem_dependency_check {
      defined?(Twitter) &&
        Devise.omniauth_providers.include?(:twitter) &&
        ENV['TWITTER_OAUTH_KEY'].present? &&
        ENV['TWITTER_OAUTH_SECRET'].present?
    }
  end

  def validate_twitter_options
    unless twitter_consumer_key.present? &&
        twitter_consumer_secret.present? &&
        twitter_oauth_token.present? &&
        twitter_oauth_token_secret.present?
      errors.add(
        :base,
        "Twitter consumer_key, consumer_secret, oauth_token, and oauth_token_secret are required to authenticate with the Twitter API.  You can provide these as options to this Agent, or as Credentials with the same names, but starting with 'twitter_'."
      )
    end
  end

  def twitter_consumer_key
    (config = Devise.omniauth_configs[:twitter]) && config.strategy.consumer_key
  end

  def twitter_consumer_secret
    (config = Devise.omniauth_configs[:twitter]) && config.strategy.consumer_secret
  end

  def twitter_oauth_token
    service && service.token
  end

  def twitter_oauth_token_secret
    service && service.secret
  end

  def twitter
    @twitter ||= Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_consumer_key
      config.consumer_secret = twitter_consumer_secret
      config.access_token = twitter_oauth_token
      config.access_token_secret = twitter_oauth_token_secret
    end
  end

  HTML_ENTITIES = {
    '&amp;' => '&',
    '&lt;' => '<',
    '&gt;' => '>',
  }
  RE_HTML_ENTITIES = Regexp.union(HTML_ENTITIES.keys)

  def format_tweet(tweet)
    attrs =
      case tweet
      when Twitter::Tweet
        tweet.attrs
      when Hash
        if tweet.key?(:id)
          tweet
        else
          tweet.deep_symbolize_keys
        end
      else
        raise TypeError, "Unexpected tweet type: #{tweet.class}"
      end

    text = (attrs[:full_text] || attrs[:text])&.dup or return attrs

    expanded_text = text.dup.tap { |text|
      attrs.dig(:entities, :urls)&.reverse_each do |entity|
        from, to = entity[:indices]
        text[from...to] = entity[:expanded_url]
      end
    }
    text.gsub!(RE_HTML_ENTITIES, HTML_ENTITIES)
    expanded_text.gsub!(RE_HTML_ENTITIES, HTML_ENTITIES)

    attrs[:text] &&= text
    attrs[:full_text] &&= text

    attrs.update(expanded_text:)
  end

  module_function :format_tweet

  module ClassMethods
    def twitter_dependencies_missing
      if ENV['TWITTER_OAUTH_KEY'].blank? || ENV['TWITTER_OAUTH_SECRET'].blank?
        "## Set TWITTER_OAUTH_KEY and TWITTER_OAUTH_SECRET in your environment to use Twitter Agents."
      elsif !defined?(Twitter) || !Devise.omniauth_providers.include?(:twitter)
        "## Include the `twitter`, `omniauth-twitter`, and `cantino-twitter-stream` gems in your Gemfile to use Twitter Agents."
      end
    end

    def tweet_event_description(text_key, extra_fields = nil)
      <<~MD.indent(4)
        {
          #{extra_fields&.indent(2)}// ... every Tweet field, including ...
          // Huginn automatically decodes "&lt;", "&gt;", and "&amp;" to "<", ">", and "&".
          "#{text_key}": "something https://t.co/XXXX",
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
          "lang": "en",
          // Huginn adds this field, expanding all shortened t.co URLs in "#{text_key}".
          "expanded_text": "something https://example.org/foo/bar"
        }
      MD
    end
  end
end

class Twitter::Error
  remove_const :FORBIDDEN_MESSAGES

  FORBIDDEN_MESSAGES = proc do |message|
    case message
    when /(?=.*status).*duplicate/i
      # - "Status is a duplicate."
      Twitter::Error::DuplicateStatus
    when /already favorited/i
      # - "You have already favorited this status."
      Twitter::Error::AlreadyFavorited
    when /already retweeted|Share validations failed/i
      # - "You have already retweeted this Tweet." (Nov 2017-)
      # - "You have already retweeted this tweet." (?-Nov 2017)
      # - "sharing is not permissible for this status (Share validations failed)" (-? 2017)
      Twitter::Error::AlreadyRetweeted
    end
  end
end
