# frozen_string_literal: true

require 'rails_helper'

describe Agents::XquikSearchAgent do
  before do
    @agent = Agents::XquikSearchAgent.new(
      name: 'Xquik search',
      options: {
        api_key: 'test-api-key',
        query: 'from:example "agent workflows"',
        limit: '2',
        query_type: 'Latest',
        expected_update_period_in_days: '2'
      }
    )
    @agent.user = users(:bob)
    @agent.save!

    @response_body = File.read(Rails.root.join('spec/data_fixtures/xquik_search_tweets.json'))
  end

  def stub_search(body: @response_body, status: 200)
    stub_request(:get, Agents::XquikSearchAgent::XQUIK_SEARCH_URL)
      .with(
        query: {
          'limit' => '2',
          'q' => 'from:example "agent workflows"',
          'queryType' => @agent.options['query_type']
        },
        headers: {
          'Accept' => 'application/json',
          'x-api-key' => 'test-api-key'
        }
      )
      .to_return(
        status:,
        body:,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#validation' do
    it 'is valid with complete options' do
      expect(@agent).to be_valid
    end

    it 'requires an API key' do
      @agent.options['api_key'] = ''

      expect(@agent).not_to be_valid
    end

    it 'requires a query' do
      @agent.options['query'] = ''

      expect(@agent).not_to be_valid
    end

    it 'validates the result limit' do
      %w[0 101 2.5 results].each do |invalid_limit|
        @agent.options['limit'] = invalid_limit
        expect(@agent).not_to be_valid
      end
    end

    it 'validates the query type' do
      @agent.options['query_type'] = 'Recent'

      expect(@agent).not_to be_valid
    end

    it 'requires a positive expected update period' do
      @agent.options['expected_update_period_in_days'] = '0'

      expect(@agent).not_to be_valid
    end
  end

  describe '#check' do
    it 'creates one event per new result in chronological order' do
      stub_search

      expect { @agent.check }.to change { @agent.events.count }.by(2)
      created_events = @agent.events.reorder(:id).last(2)
      expect(created_events.map { |event| event.payload['id'] }).to eq(
        %w[1912345678901234567 1912345678901234568]
      )
      expect(created_events.last.payload.dig('author', 'username')).to eq('example_researcher')
    end

    it 'sends the configured query, limit, sort order, and API key' do
      request = stub_search

      @agent.check

      expect(request).to have_been_requested.once
    end

    it 'preserves engagement ranking for Top results' do
      @agent.options['query_type'] = 'Top'
      stub_search

      @agent.check

      expect(@agent.events.reorder(:id).last(2).map { |event| event.payload['id'] }).to eq(
        %w[1912345678901234568 1912345678901234567]
      )
    end

    it 'does not emit a result twice' do
      stub_search

      @agent.check

      expect { @agent.check }.not_to(change { @agent.events.count })
    end

    it 'keeps a bounded history of result IDs' do
      @agent.memory['seen_ids'] = 500.times.map { |index| "old-#{index}" }
      stub_search

      @agent.check

      expect(@agent.memory['seen_ids'].length).to eq(Agents::XquikSearchAgent::REMEMBERED_ID_COUNT)
      expect(@agent.memory['seen_ids'].first(2)).to eq(
        %w[1912345678901234568 1912345678901234567]
      )
    end

    it 'logs API errors without emitting events' do
      stub_search(
        body: { error: 'rate_limit_exceeded', message: 'Rate limit exceeded' }.to_json,
        status: 429
      )

      expect { @agent.check }.to change { @agent.logs.count }.by(1)
      expect(@agent.events).to be_empty
      expect(@agent.logs.last.message).to eq('Xquik API request failed (HTTP 429): Rate limit exceeded')
    end

    it 'logs string API errors without raising' do
      stub_search(body: { error: 'Account credits exhausted' }.to_json, status: 402)

      expect { @agent.check }.to change { @agent.logs.count }.by(1)
      expect(@agent.events).to be_empty
      expect(@agent.logs.last.message).to eq('Xquik API request failed (HTTP 402): Account credits exhausted')
    end

    it 'rejects malformed success responses' do
      stub_search(body: { tweets: [{ id: '1912345678901234567' }] }.to_json)

      expect { @agent.check }.to change { @agent.logs.count }.by(1)
      expect(@agent.events).to be_empty
      expect(@agent.logs.last.message).to eq('Xquik API returned an invalid search response')
    end
  end

  describe '#working?' do
    it 'is working after a recent event' do
      stub_search
      @agent.check

      expect(@agent).to be_working
    end
  end
end
