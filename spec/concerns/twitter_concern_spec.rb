require 'rails_helper'

describe TwitterConcern do
  class TestTwitterAgent < Agent
    include TwitterConcern
  end

  before do
    allow(TestTwitterAgent).to receive(:valid_type?).with("TestTwitterAgent") { true }

    @agent = TestTwitterAgent.create(name: "some agent") { |agent|
      agent.user = users(:bob)
    }
  end

  describe 'format_tweet' do
    let(:tweet_hash) {
      {
        created_at: "Wed Mar 01 01:52:07 +0000 2023",
        id: 9_000_000_000_000_000_000,
        id_str: "9000000000000000000",
        full_text: "Test &gt; Test &amp; https://t.co/XXXXXXXXXX &amp; Test &lt; https://t.co/YYYYYYYYYY",
        truncated: false,
        display_text_range: [
          0,
          84
        ],
        entities: {
          hashtags: [],
          symbols: [],
          user_mentions: [],
          urls: [
            {
              url: "https://t.co/XXXXXXXXXX",
              expanded_url: "https://example.org/foo/bar/baz.html",
              display_url: "example.org/foo/bar/baz…",
              indices: [
                21,
                44
              ]
            },
            {
              url: "https://t.co/YYYYYYYYYY",
              expanded_url: "https://example.com/quux/",
              display_url: "example.org/quux/",
              indices: [
                61,
                84
              ]
            }
          ]
        },
      }
    }
    let(:expected) {
      {
        created_at: "Wed Mar 01 01:52:07 +0000 2023",
        id: 9_000_000_000_000_000_000,
        id_str: "9000000000000000000",
        full_text: "Test > Test & https://t.co/XXXXXXXXXX & Test < https://t.co/YYYYYYYYYY",
        expanded_text: "Test > Test & https://example.org/foo/bar/baz.html & Test < https://example.com/quux/",
        truncated: false,
        display_text_range: [
          0,
          84
        ],
        entities: {
          hashtags: [],
          symbols: [],
          user_mentions: [],
          urls: [
            {
              url: "https://t.co/XXXXXXXXXX",
              expanded_url: "https://example.org/foo/bar/baz.html",
              display_url: "example.org/foo/bar/baz…",
              indices: [
                21,
                44
              ]
            },
            {
              url: "https://t.co/YYYYYYYYYY",
              expanded_url: "https://example.com/quux/",
              display_url: "example.org/quux/",
              indices: [
                61,
                84
              ]
            }
          ]
        },
      }
    }
    let(:input) { tweet_hash }
    subject { @agent.send(:format_tweet, input) }

    it "formats a tweet" do
      expect(subject).to eq(expected)
    end

    context "when a string key hash is given" do
      let(:input) { tweet_hash.deep_stringify_keys }
      it "formats a tweet" do
        expect(subject).to eq(expected)
      end
    end

    context "when a Twitter::Tweet object is given" do
      let(:input) { Twitter::Tweet.new(tweet_hash) }
      let(:expected) { super().then { |attrs| attrs.update(text: attrs[:full_text]) } }
      it "formats a tweet" do
        expect(subject).to eq(expected)
      end
    end

    context "when nil is given" do
      let(:input) { nil }
      it "raises an exception" do
        expect { subject }.to raise_exception(TypeError)
      end
    end
  end
end
