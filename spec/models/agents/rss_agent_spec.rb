require 'rails_helper'

describe Agents::RssAgent do
  before do
    @valid_options = {
      'expected_update_period_in_days' => "2",
      'url' => "https://github.com/cantino/huginn/commits/master.atom",
    }

    stub_request(:any, /github.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/github_rss.atom")), :status => 200)
    stub_request(:any, /SlickdealsnetFP/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/slickdeals.atom")), :status => 200)
    stub_request(:any, /onethingwell.org/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/onethingwell.atom")), :status => 200)
  end

  let(:agent) do
    _agent = Agents::RssAgent.new(:name => "rss feed", :options => @valid_options)
    _agent.user = users(:bob)
    _agent.save!
    _agent
  end

  it_behaves_like WebRequestConcern

  describe "validations" do
    it "should validate the presence of url" do
      agent.options['url'] = "http://google.com"
      expect(agent).to be_valid

      agent.options['url'] = ["http://google.com", "http://yahoo.com"]
      expect(agent).to be_valid

      agent.options['url'] = ""
      expect(agent).not_to be_valid

      agent.options['url'] = nil
      expect(agent).not_to be_valid
    end

    it "should validate the presence and numericality of expected_update_period_in_days" do
      agent.options['expected_update_period_in_days'] = "5"
      expect(agent).to be_valid

      agent.options['expected_update_period_in_days'] = "wut?"
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = 0
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = nil
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = ""
      expect(agent).not_to be_valid
    end
  end

  describe "emitting RSS events" do
    it "should emit items as events for an Atom feed" do
      agent.options['include_feed_info'] = true

      expect {
        agent.check
      }.to change { agent.events.count }.by(20)

      first, *, last = agent.events.last(20)
      [first, last].each do |event|
        expect(first.payload['feed']).to include({
                                                   "type" => "atom",
                                                   "title" => "Recent Commits to huginn:master",
                                                   "url" => "https://github.com/cantino/huginn/commits/master",
                                                   "links" => [
                                                     {
                                                       "type" => "text/html",
                                                       "rel" => "alternate",
                                                       "href" => "https://github.com/cantino/huginn/commits/master",
                                                     },
                                                     {
                                                       "type" => "application/atom+xml",
                                                       "rel" => "self",
                                                       "href" => "https://github.com/cantino/huginn/commits/master.atom",
                                                     },
                                                   ],
                                                 })
      end
      expect(first.payload['url']).to eq("https://github.com/cantino/huginn/commit/d0a844662846cf3c83b94c637c1803f03db5a5b0")
      expect(first.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/d0a844662846cf3c83b94c637c1803f03db5a5b0"])
      expect(first.payload['links']).to eq([
                                             {
                                               "href" => "https://github.com/cantino/huginn/commit/d0a844662846cf3c83b94c637c1803f03db5a5b0",
                                               "rel" => "alternate",
                                               "type" => "text/html",
                                             }
                                          ])
      expect(first.payload['authors']).to eq(["cantino (https://github.com/cantino)"])
      expect(first.payload['date_published']).to be_nil
      expect(first.payload['last_updated']).to eq("2014-07-16T22:26:22-07:00")
      expect(last.payload['url']).to eq("https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af")
      expect(last.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af"])
      expect(last.payload['links']).to eq([
                                              {
                                                "href" => "https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af",
                                                "rel" => "alternate",
                                                "type" => "text/html",
                                              }
                                          ])
      expect(last.payload['authors']).to eq(["CloCkWeRX (https://github.com/CloCkWeRX)"])
      expect(last.payload['date_published']).to be_nil
      expect(last.payload['last_updated']).to eq("2014-07-01T16:37:47+09:30")
    end

    it "should emit items as events in the order specified in the events_order option" do
      expect {
        agent.options['events_order'] = ['{{title | replace_regex: "^[[:space:]]+", "" }}']
        agent.check
      }.to change { agent.events.count }.by(20)

      first, *, last = agent.events.last(20)
      expect(first.payload['title'].strip).to eq('upgrade rails and gems')
      expect(first.payload['url']).to eq("https://github.com/cantino/huginn/commit/87a7abda23a82305d7050ac0bb400ce36c863d01")
      expect(first.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/87a7abda23a82305d7050ac0bb400ce36c863d01"])
      expect(last.payload['title'].strip).to eq('Dashed line in a diagram indicates propagate_immediately being false.')
      expect(last.payload['url']).to eq("https://github.com/cantino/huginn/commit/0e80f5341587aace2c023b06eb9265b776ac4535")
      expect(last.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/0e80f5341587aace2c023b06eb9265b776ac4535"])
    end

    it "should emit items as events for a FeedBurner RSS 2.0 feed" do
      agent.options['url'] = "http://feeds.feedburner.com/SlickdealsnetFP?format=atom" # This is actually RSS 2.0 w/ Atom extension
      agent.options['include_feed_info'] = true
      agent.save!

      expect {
        agent.check
      }.to change { agent.events.count }.by(79)

      first, *, last = agent.events.last(79)
      expect(first.payload['feed']).to include({
                                                 "type" => "rss",
                                                 "title" => "SlickDeals.net",
                                                 "description" => "Slick online shopping deals.",
                                                 "url" => "http://slickdeals.net/",
                                               })
      # Feedjira extracts feedburner:origLink
      expect(first.payload['url']).to eq("http://slickdeals.net/permadeal/130160/green-man-gaming---pc-games-tomb-raider-game-of-the-year-6-hitman-absolution-elite-edition")
      expect(last.payload['feed']).to include({
                                                "type" => "rss",
                                                "title" => "SlickDeals.net",
                                                "description" => "Slick online shopping deals.",
                                                "url" => "http://slickdeals.net/",
                                              })
      expect(last.payload['url']).to eq("http://slickdeals.net/permadeal/129980/amazon---rearth-ringke-fusion-bumper-hybrid-case-for-iphone-6")
    end

    it "should track ids and not re-emit the same item when seen again" do
      agent.check
      expect(agent.memory['seen_ids']).to eq(agent.events.map {|e| e.payload['id'] })

      newest_id = agent.memory['seen_ids'][0]
      expect(agent.events.first.payload['id']).to eq(newest_id)
      agent.memory['seen_ids'] = agent.memory['seen_ids'][1..-1] # forget the newest id

      expect {
        agent.check
      }.to change { agent.events.count }.by(1)

      expect(agent.events.first.payload['id']).to eq(newest_id)
      expect(agent.memory['seen_ids'][0]).to eq(newest_id)
    end

    it "should truncate the seen_ids in memory at 500 items" do
      agent.memory['seen_ids'] = ['x'] * 490
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(500)
    end

    it "should support an array of URLs" do
      agent.options['url'] = ["https://github.com/cantino/huginn/commits/master.atom", "http://feeds.feedburner.com/SlickdealsnetFP?format=atom"]
      agent.save!

      expect {
        agent.check
      }.to change { agent.events.count }.by(20 + 79)
    end

    it "should fetch one event per run" do
      agent.options['url'] = ["https://github.com/cantino/huginn/commits/master.atom"]

      agent.options['max_events_per_run'] = 1
      agent.check
      expect(agent.events.count).to eq(1)
    end

    it "should fetch all events per run" do
      agent.options['url'] = ["https://github.com/cantino/huginn/commits/master.atom"]

      # <= 0 should ignore option and get all
      agent.options['max_events_per_run'] = 0
      agent.check
      expect(agent.events.count).to eq(20)

      agent.options['max_events_per_run'] = -1
      expect {
        agent.check
      }.to_not change { agent.events.count }
    end

  end

  context "when no ids are available" do
    before do
      @valid_options['url'] = 'http://feeds.feedburner.com/SlickdealsnetFP?format=atom'
    end

    it "calculates content MD5 sums" do
      expect {
        agent.check
      }.to change { agent.events.count }.by(79)
      expect(agent.memory['seen_ids']).to eq(agent.events.map {|e| Digest::MD5.hexdigest(e.payload['content']) })
    end
  end

  context "parsing feeds" do
    before do
      @valid_options['url'] = 'http://onethingwell.org/rss'
    end

    it "captures timestamps normalized in the ISO 8601 format" do
      agent.check
      first, *, third = agent.events.take(3)
      expect(first.payload['date_published']).to eq('2015-08-20T17:00:10+01:00')
      expect(third.payload['date_published']).to eq('2015-08-20T13:00:07+01:00')
    end

    it "captures multiple categories" do
      agent.check
      first, *, third = agent.events.take(3)
      expect(first.payload['categories']).to eq(["csv", "crossplatform", "utilities"])
      expect(third.payload['categories']).to eq(["web"])
    end

    it "sanitizes HTML content" do
      agent.options['clean'] = true
      agent.check
      event = agent.events.last
      expect(event.payload['content']).to eq('<a href="http://showgoers.tv/">Showgoers</a>: <blockquote> <p>Showgoers is a Chrome browser extension to synchronize your Netflix player with someone else so that you can co-watch the same movie on different computers with no hassle. Syncing up your player is as easy as sharing a URL.</p> </blockquote>')
      expect(event.payload['description']).to eq('<a href="http://showgoers.tv/">Showgoers</a>: <blockquote> <p>Showgoers is a Chrome browser extension to synchronize your Netflix player with someone else so that you can co-watch the same movie on different computers with no hassle. Syncing up your player is as easy as sharing a URL.</p> </blockquote>')
    end

    it "captures an enclosure" do
      agent.check
      event = agent.events.fourth
      expect(event.payload['enclosure']).to eq({ "url" => "http://c.1tw.org/images/2015/itsy.png", "type" => "image/png", "length" => "48249" })
      expect(event.payload['image']).to eq("http://c.1tw.org/images/2015/itsy.png")
    end
  end

  describe 'logging errors with the feed url' do
    it 'includes the feed URL when an exception is raised' do
      mock(Feedjira::Feed).parse(anything) { raise StandardError.new("Some error!") }
      expect(lambda {
        agent.check
      }).not_to raise_error
      expect(agent.logs.last.message).to match(%r[Failed to fetch https://github.com])
    end
  end
end
