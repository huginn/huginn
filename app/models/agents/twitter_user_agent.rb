require "twitter"

module Agents
  class TwitterUserAgent < Agent
    cannot_receive_events!

    description <<-MD
      The TwitterUserAgent follows the timeline of a specified Twitter user.

      You must set up a Twitter app and provide it's `consumer_key`, `consumer_secret`, `oauth_token` and `oauth_token_secret`, (Also shown as "Access token" on the Twitter developer's site.) along with the `username` of the Twitter user to monitor.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description <<-MD
      Events are the raw JSON provided by the Twitter API. Should look something like:

        {
         :created_at=>"Thu Apr 04 13:27:48 +0000 2013",
         :id=>319803490421596160,
         :id_str=>"319803490421596160",
         :text=>
          "In which @jeresig goes to an art gallery and is \"the JavaScript programmer\". http://t.co/gt3PT1d3G1",
         :source=>
          "<a href=\"http://itunes.apple.com/us/app/twitter/id409789998?mt=12\" rel=\"nofollow\">Twitter for Mac</a>",
         :truncated=>false,
         :in_reply_to_status_id=>nil,
         :in_reply_to_status_id_str=>nil,
         :in_reply_to_user_id=>nil,
         :in_reply_to_user_id_str=>nil,
         :in_reply_to_screen_name=>nil,
         :user=>
          {:id=>2341001,
           :id_str=>"2341001",
           :name=>"Albert Sun",
           :screen_name=>"albertsun",
           :location=>"New York, NY",
           :description=>
            "News apps developer at NYT, formerly WSJ. graduated Penn 2010, geek, journalist, data-viz, nlp, gis, digital economics =)",
           :url=>"http://albertsun.info",
           :entities=>
            {:url=>
              {:urls=>
                [{:url=>"http://albertsun.info",
                  :expanded_url=>nil,
                  :indices=>[0, 21]}]},
             :description=>{:urls=>[]}},
           :protected=>false,
           :followers_count=>1857,
           :friends_count=>798,
           :listed_count=>115,
           :created_at=>"Mon Mar 26 19:22:05 +0000 2007",
           :favourites_count=>9,
           :utc_offset=>-18000,
           :time_zone=>"Eastern Time (US & Canada)",
           :geo_enabled=>false,
           :verified=>false,
           :statuses_count=>2572,
           :lang=>"en",
           :contributors_enabled=>false,
           :is_translator=>false,
           :profile_background_color=>"1B2A2B",
           :profile_background_image_url=>
            "http://a0.twimg.com/profile_background_images/2802438/twitterbg.jpg",
           :profile_background_image_url_https=>
            "https://si0.twimg.com/profile_background_images/2802438/twitterbg.jpg",
           :profile_background_tile=>false,
           :profile_image_url=>
            "http://a0.twimg.com/profile_images/110500205/profile-square_normal.jpg",
           :profile_image_url_https=>
            "https://si0.twimg.com/profile_images/110500205/profile-square_normal.jpg",
           :profile_link_color=>"0000FF",
           :profile_sidebar_border_color=>"87BC44",
           :profile_sidebar_fill_color=>"E0FF92",
           :profile_text_color=>"000000",
           :profile_use_background_image=>true,
           :default_profile=>false,
           :default_profile_image=>false,
           :following=>false,
           :follow_request_sent=>false,
           :notifications=>false},
         :geo=>nil,
         :coordinates=>nil,
         :place=>nil,
         :contributors=>nil,
         :retweet_count=>0,
         :favorite_count=>0,
         :entities=>
          {:hashtags=>[],
           :urls=>
            [{:url=>"http://t.co/gt3PT1d3G1",
              :expanded_url=>
               "http://www.nytimes.com/2013/04/04/fashion/art-and-techology-a-clash-of-cultures.html?pagewanted=all",
              :display_url=>"nytimes.com/2013/04/04/fas",
              :indices=>[77, 99]}],
           :user_mentions=>
            [{:screen_name=>"jeresig",
              :name=>"John Resig",
              :id=>752673,
              :id_str=>"752673",
              :indices=>[9, 17]}]},
         :favorited=>false,
         :retweeted=>false,
         :possibly_sensitive=>false,
         :lang=>"en"
        }
    MD

    default_schedule "every_1h"

    def validate_options
      unless options[:username].present? && options[:expected_update_period_in_days].present? && options[:consumer_key].present? && options[:consumer_secret].present? && options[:oauth_token].present? && options[:oauth_token_secret].present?
        errors.add(:base, "expected_update_period_in_days, username, consumer_key, consumer_secret, oauth_token and oauth_token_secret are required")
      end
    end

    def working?
      (event = event_created_within(options[:expected_update_period_in_days].to_i.days)) && event.payload.present?
    end

    def default_options
      {
          :username => "tectonic",
          :expected_update_period_in_days => "2",
          :consumer_key => "---",
          :consumer_secret => "---",
          :oauth_token => "---",
          :oauth_token_secret => "---"
      }
    end

    def check
      Twitter.configure do |config|
        config.consumer_key = options[:consumer_key]
        config.consumer_secret = options[:consumer_secret]
        config.oauth_token = options[:oauth_token]
        config.oauth_token_secret = options[:oauth_token_secret]
      end

      since_id = memory[:since_id] || nil
      opts = {:count => 200, :include_rts => true, :exclude_replies => false, :include_entities => true, :contributor_details => true}
      opts.merge! :since_id => since_id unless since_id.nil?

      tweets = Twitter.user_timeline(options[:username], opts)

      tweets.each do |tweet|
        memory[:since_id] = tweet.id if !memory[:since_id] || (tweet.id > memory[:since_id])

        create_event :payload => tweet.attrs
      end

      save!
    end
  end
end