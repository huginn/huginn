# frozen_string_literal: true

module Agents
  # Searches public X posts through Xquik and emits unseen results.
  class XquikSearchAgent < Agent
    include WebRequestConcern

    XQUIK_SEARCH_URL = 'https://xquik.com/api/v1/x/tweets/search'
    REMEMBERED_ID_COUNT = 500

    can_dry_run!
    cannot_receive_events!

    description <<~MD
      The Xquik Search Agent searches public X posts and emits new results as Events.
      Create an API key in [Xquik](https://xquik.com). Store it in a Huginn credential named `xquik_api_key`, or replace the `api_key` option. Public search does not require a connected X account.
      Xquik is an independent third-party service. It is not affiliated with X Corp.
      Set `query` to keywords or [X search operators](https://docs.xquik.com/api-reference/x/search-tweets), such as `from:openai "agents sdk"`.
      Set `limit` between 1 and 100. Xquik can return fewer results when fewer posts match or account credits are limited.
      Search costs 1 Xquik credit per returned post.
      Set `query_type` to `Latest` for chronological results or `Top` for engagement-ranked results.
      Set `expected_update_period_in_days` to the maximum expected gap between emitted Events.
    MD

    event_description <<~MD
      Events contain one public X post returned by Xquik. Optional fields are omitted when unavailable.

          { "id": "1912345678901234567", "text": "Example post", "createdAt": "2026-08-24T08:00:00.000Z", "author": { "username": "example_user" } }
    MD

    default_schedule 'every_1h'

    def default_options
      {
        'api_key' => '{% credential xquik_api_key %}',
        'query' => 'machine learning',
        'limit' => '20',
        'query_type' => 'Latest',
        'expected_update_period_in_days' => '2'
      }
    end

    def validate_options
      validate_required_options
      errors.add(:base, 'expected_update_period_in_days must be a positive integer') unless valid_update_period?
      errors.add(:base, 'limit must be an integer between 1 and 100') unless valid_limit?
      errors.add(:base, 'query_type must be Latest or Top') unless %w[Latest Top].include?(options['query_type'])
      validate_web_request_options!
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def check
      tweets = fetch_tweets
      return unless tweets

      ordered_unseen_tweets(tweets).each do |tweet|
        create_event payload: tweet
      end

      remember(tweets)
      save!
    rescue Faraday::Error => e
      error("Xquik API request failed: #{e.message.truncate(500)}")
    end

    def parse_body?
      true
    end

    private

    def validate_required_options
      errors.add(:base, 'api_key is required') if options['api_key'].blank?
      errors.add(:base, 'query is required') if options['query'].blank?
    end

    def valid_limit?
      limit = options['limit']
      limit.present? && limit.to_s == limit.to_i.to_s && (1..100).cover?(limit.to_i)
    end

    def valid_update_period?
      period = options['expected_update_period_in_days']
      period.present? && period.to_s == period.to_i.to_s && period.to_i.positive?
    end

    def fetch_tweets
      response = faraday.get(
        XQUIK_SEARCH_URL,
        { q: interpolated['query'], limit: interpolated['limit'].to_i, queryType: interpolated['query_type'] },
        { 'Accept' => 'application/json', 'x-api-key' => interpolated['api_key'] }
      )
      return log_api_error(response) unless response.success?

      tweets = response.body['tweets'] if response.body.is_a?(Hash)
      return tweets if valid_tweets?(tweets)

      error('Xquik API returned an invalid search response')
      nil
    end

    def valid_tweets?(tweets)
      tweets.is_a?(Array) && tweets.all? do |tweet|
        tweet.is_a?(Hash) && tweet['id'].present? && tweet['text'].is_a?(String)
      end
    end

    def unseen_tweets(tweets)
      seen_ids = Set.new(Array(memory['seen_ids']).map(&:to_s))

      tweets.each_with_object([]) do |tweet, unseen|
        unseen << tweet if seen_ids.add?(tweet['id'].to_s)
      end
    end

    def ordered_unseen_tweets(tweets)
      unseen = unseen_tweets(tweets)
      interpolated['query_type'] == 'Latest' ? unseen.reverse : unseen
    end

    def remember(tweets)
      fetched_ids = tweets.map { |tweet| tweet['id'].to_s }
      memory['seen_ids'] = (fetched_ids + Array(memory['seen_ids']).map(&:to_s)).uniq.first(REMEMBERED_ID_COUNT)
    end

    def log_api_error(response)
      message = api_error_message(response.body)
      message = 'Check the API key, query, and available credits' unless message.is_a?(String) && message.present?
      error("Xquik API request failed (HTTP #{response.status}): #{message.truncate(500)}")
      nil
    end

    def api_error_message(body)
      return unless body.is_a?(Hash)

      api_error = body['error']
      return body['message'] if body['message'].present?
      return api_error['message'] if api_error.is_a?(Hash)

      api_error if api_error.is_a?(String)
    end
  end
end
