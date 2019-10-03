require 'rails_helper'

describe Agents::RssAgent do
  before do
    @valid_options = {
      'expected_update_period_in_days' => "2",
      'url' => "https://github.com/cantino/huginn/commits/master.atom",
    }

    stub_request(:any, /github.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/github_rss.atom")), :status => 200)
    stub_request(:any, /bad.github.com/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/github_rss.atom")).gsub(/<link [^>]+\/>/, '<link/>'), status: 200)
    stub_request(:any, /SlickdealsnetFP/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/slickdeals.atom")), :status => 200)
    stub_request(:any, /onethingwell.org/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/onethingwell.rss")), status: 200)
    stub_request(:any, /bad.onethingwell.org/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/onethingwell.rss")).gsub(/(?<=<link>)[^<]*/, ''), status: 200)
    stub_request(:any, /iso-8859-1/).to_return(body: File.binread(Rails.root.join("spec/data_fixtures/iso-8859-1.rss")), headers: { 'Content-Type' => 'application/rss+xml; charset=ISO-8859-1' }, status: 200)
    stub_request(:any, /podcast/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/podcast.rss")), status: 200)
    stub_request(:any, /youtube/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/youtube.xml")), status: 200)
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
      agent.options['include_sort_info'] = true

      expect {
        agent.check
      }.to change { agent.events.count }.by(20)

      first, *, last = agent.events.last(20)
      [first, last].each do |event|
        expect(event.payload['feed']).to include({
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
      expect(first.payload['sort_info']).to eq({ 'position' => 20, 'count' => 20 })
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
      expect(last.payload['sort_info']).to eq({ 'position' => 1, 'count' => 20 })
    end

    it "should emit items as events in the order specified in the events_order option" do
      expect {
        agent.options['events_order'] = ['{{title | replace_regex: "^[[:space:]]+", "" }}']
        agent.options['include_sort_info'] = true
        agent.check
      }.to change { agent.events.count }.by(20)

      first, *, last = agent.events.last(20)
      expect(first.payload['title'].strip).to eq('upgrade rails and gems')
      expect(first.payload['url']).to eq("https://github.com/cantino/huginn/commit/87a7abda23a82305d7050ac0bb400ce36c863d01")
      expect(first.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/87a7abda23a82305d7050ac0bb400ce36c863d01"])
      expect(first.payload['sort_info']).to eq({ 'position' => 20, 'count' => 20 })
      expect(last.payload['title'].strip).to eq('Dashed line in a diagram indicates propagate_immediately being false.')
      expect(last.payload['url']).to eq("https://github.com/cantino/huginn/commit/0e80f5341587aace2c023b06eb9265b776ac4535")
      expect(last.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/0e80f5341587aace2c023b06eb9265b776ac4535"])
      expect(last.payload['sort_info']).to eq({ 'position' => 1, 'count' => 20 })
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

    it "should truncate the seen_ids in memory at 500 items per default" do
      agent.memory['seen_ids'] = ['x'] * 490
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(500)
    end
    
    it "should truncate the seen_ids in memory at amount of items configured in options" do
      agent.options['remembered_id_count'] = "600"
      agent.memory['seen_ids'] = ['x'] * 590
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(600)
    end
    
    it "should truncate the seen_ids after configuring a lower limit of items when check is executed" do
      agent.memory['seen_ids'] = ['x'] * 600
      agent.options['remembered_id_count'] = "400"
      expect(agent.memory['seen_ids'].length).to eq(600)
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(400)
    end
    
    it "should truncate the seen_ids at default after removing custom limit" do
      agent.options['remembered_id_count'] = "600"
      agent.memory['seen_ids'] = ['x'] * 590
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(600)

      agent.options.delete('remembered_id_count')
      agent.memory['seen_ids'] = ['x'] * 590
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

    it "ignores an empty author" do
      agent.check
      event = agent.events.first
      expect(event.payload['authors']).to eq([])
    end

    context 'with an empty link in RSS' do
      before do
        @valid_options['url'] = 'http://bad.onethingwell.org/rss'
      end

      it "does not leak :no_buffer" do
        agent.check
        event = agent.events.first
        expect(event.payload['links']).to eq([])
      end
    end

    context 'with an empty link in RSS' do
      before do
        @valid_options['url'] = "https://bad.github.com/cantino/huginn/commits/master.atom"
      end

      it "does not leak :no_buffer" do
        agent.check
        event = agent.events.first
        expect(event.payload['links']).to eq([])
      end
    end

    context 'with the encoding declared in both headers and the content' do
      before do
        @valid_options['url'] = 'http://example.org/iso-8859-1.rss'
      end

      it "decodes the content properly" do
        agent.check
        event = agent.events.first
        expect(event.payload['title']).to eq('Mëkanïk Zaïn')
      end

      it "decodes the content properly with force_encoding specified" do
        @valid_options['force_encoding'] = 'iso-8859-1'
        agent.check
        event = agent.events.first
        expect(event.payload['title']).to eq('Mëkanïk Zaïn')
      end
    end

    context 'with podcast elements' do
      before do
        @valid_options['url'] = 'http://example.com/podcast.rss'
        @valid_options['include_feed_info'] = true
      end

      let :feed_info do
        {
          "id" => nil,
          "type" => "rss",
          "url" => "http://www.example.com/podcasts/everything/index.html",
          "links" => [ { "href" => "http://www.example.com/podcasts/everything/index.html" } ],
          "title" => "All About Everything",
          "description" => "All About Everything is a show about everything. Each week we dive into any subject known to man and talk about it as much as we can. Look for our podcast in the Podcasts app or in the iTunes Store",
          "copyright" => "℗ & © 2014 John Doe & Family",
          "generator" => nil,
          "icon" => nil,
          "authors" => [
            "John Doe"
          ],
          "date_published" => nil,
          "last_updated" => nil,
          "itunes_categories" => [
            "Technology", "Gadgets",
            "TV & Film",
            "Arts", "Food"
          ],
          "itunes_complete" => "yes",
          "itunes_explicit" => "no",
          "itunes_image" => "http://example.com/podcasts/everything/AllAboutEverything.jpg",
          "itunes_owners" => ["John Doe <john.doe@example.com>"],
          "itunes_subtitle" => "A show about everything",
          "itunes_summary" => "All About Everything is a show about everything. Each week we dive into any subject known to man and talk about it as much as we can. Look for our podcast in the Podcasts app or in the iTunes Store",
          "language" => "en-us"
        }
      end

      it "is parsed correctly" do
        expect {
          agent.check
        }.to change { agent.events.count }.by(4)

        expect(agent.events.map(&:payload)).to match([
          {
            "feed" => feed_info,
            "id" => "http://example.com/podcasts/archive/aae20140601.mp3",
            "url" => "http://example.com/podcasts/archive/aae20140601.mp3",
            "urls" => ["http://example.com/podcasts/archive/aae20140601.mp3"],
            "links" => [],
            "title" => "Red,Whine, & Blue",
            "description" => nil,
            "content" => nil,
            "image" => nil,
            "enclosure" => {
              "url" => "http://example.com/podcasts/everything/AllAboutEverythingEpisode4.mp3",
              "type" => "audio/mpeg",
              "length" => "498537"
            },
            "authors" => ["<Various>"],
            "categories" => [],
            "date_published" => "2016-03-11T01:15:00+00:00",
            "last_updated" => "2016-03-11T01:15:00+00:00",
            "itunes_duration" => "03:59",
            "itunes_explicit" => "no",
            "itunes_image" => "http://example.com/podcasts/everything/AllAboutEverything/Episode4.jpg",
            "itunes_subtitle" => "Red + Blue != Purple",
            "itunes_summary" => "This week we talk about surviving in a Red state if you are a Blue person. Or vice versa."
          },
          {
            "feed" => feed_info,
            "id" => "http://example.com/podcasts/archive/aae20140697.m4v",
            "url" => "http://example.com/podcasts/archive/aae20140697.m4v",
            "urls" => ["http://example.com/podcasts/archive/aae20140697.m4v"],
            "links" => [],
            "title" => "The Best Chili",
            "description" => nil,
            "content" => nil,
            "image" => nil,
            "enclosure" => {
              "url" => "http://example.com/podcasts/everything/AllAboutEverythingEpisode2.m4v",
              "type" => "video/x-m4v",
              "length" => "5650889"
            },
            "authors" => ["Jane Doe"],
            "categories" => [],
            "date_published" => "2016-03-10T02:00:00-07:00",
            "last_updated" => "2016-03-10T02:00:00-07:00",
            "itunes_closed_captioned" => "Yes",
            "itunes_duration" => "04:34",
            "itunes_explicit" => "no",
            "itunes_image" => "http://example.com/podcasts/everything/AllAboutEverything/Episode3.jpg",
            "itunes_subtitle" => "Jane and Eric",
            "itunes_summary" => "This week we talk about the best Chili in the world. Which chili is better?"
          },
          {
            "feed" => feed_info,
            "id" => "http://example.com/podcasts/archive/aae20140608.mp4",
            "url" => "http://example.com/podcasts/archive/aae20140608.mp4",
            "urls" => ["http://example.com/podcasts/archive/aae20140608.mp4"],
            "links" => [],
            "title" => "Socket Wrench Shootout",
            "description" => nil,
            "content" => nil,
            "image" => nil,
            "enclosure" => {
              "url" => "http://example.com/podcasts/everything/AllAboutEverythingEpisode2.mp4",
              "type" => "video/mp4",
              "length" => "5650889"
            },
            "authors" => ["Jane Doe"],
            "categories" => [],
            "date_published" => "2016-03-09T13:00:00-05:00",
            "last_updated" => "2016-03-09T13:00:00-05:00",
            "itunes_duration" => "04:34",
            "itunes_explicit" => "no",
            "itunes_image" => "http://example.com/podcasts/everything/AllAboutEverything/Episode2.jpg",
            "itunes_subtitle" => "Comparing socket wrenches is fun!",
            "itunes_summary" => "This week we talk about metric vs. Old English socket wrenches. Which one is better? Do you really need both? Get all of your answers here."
          },
          {
            "feed" => feed_info,
            "id" => "http://example.com/podcasts/archive/aae20140615.m4a",
            "url" => "http://example.com/podcasts/archive/aae20140615.m4a",
            "urls" => ["http://example.com/podcasts/archive/aae20140615.m4a"],
            "links" => [],
            "title" => "Shake Shake Shake Your Spices",
            "description" => nil,
            "content" => nil,
            "image" => nil,
            "enclosure" => {
              "url" => "http://example.com/podcasts/everything/AllAboutEverythingEpisode3.m4a",
              "type" => "audio/x-m4a",
              "length" => "8727310"
            },
            "authors" => ["John Doe"],
            "categories" => [],
            "date_published" => "2016-03-08T12:00:00+00:00",
            "last_updated" => "2016-03-08T12:00:00+00:00",
            "itunes_duration" => "07:04",
            "itunes_explicit" => "no",
            "itunes_image" => "http://example.com/podcasts/everything/AllAboutEverything/Episode1.jpg",
            "itunes_subtitle" => "A short primer on table spices",
            "itunes_summary" => "This week we talk about <a href=\"https://itunes/apple.com/us/book/antique-trader-salt-pepper/id429691295?mt=11\">salt and pepper shakers</a>, comparing and contrasting pour rates, construction materials, and overall aesthetics. Come and join the party!"
          }
        ])
      end
    end

    context 'of YouTube' do
      before do
        @valid_options['url'] = 'http://example.com/youtube.xml'
        @valid_options['include_feed_info'] = true
      end

      it "is parsed correctly" do
        expect {
          agent.check
        }.to change { agent.events.count }.by(15)

        expect(agent.events.first.payload).to match({
          "feed" => {
            "id" => "yt:channel:UCoTLdfNePDQzvdEgIToLIUg",
            "type" => "atom",
            "url" => "https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg",
            "links" => [
              { "href" => "http://www.youtube.com/feeds/videos.xml?channel_id=UCoTLdfNePDQzvdEgIToLIUg", "rel" => "self" },
              { "href" => "https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg", "rel" => "alternate" }
            ],
            "title" => "SecDSM",
            "description" => nil,
            "copyright" => nil,
            "generator" => nil,
            "icon" => nil,
            "authors" => ["SecDSM (https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg)"],
            "date_published" => "2016-07-28T18:46:21+00:00",
            "last_updated" => "2016-07-28T18:46:21+00:00"
          },
          "id" => "yt:video:OCs1E0vP7Oc",
          "authors" => ["SecDSM (https://www.youtube.com/channel/UCoTLdfNePDQzvdEgIToLIUg)"],
          "categories" => [],
          "content" => nil,
          "date_published" => "2017-06-15T02:36:17+00:00",
          "description" => nil,
          "enclosure" => nil,
          "image" => nil,
          "last_updated" => "2017-06-15T02:36:17+00:00",
          "links" => [
            { "href"=>"https://www.youtube.com/watch?v=OCs1E0vP7Oc", "rel"=>"alternate" }
          ],
          "title" => "SecDSM 2017 March - Talk 01",
          "url" => "https://www.youtube.com/watch?v=OCs1E0vP7Oc",
          "urls" => ["https://www.youtube.com/watch?v=OCs1E0vP7Oc"]
        })
      end
    end
  end

  describe 'logging errors with the feed url' do
    it 'includes the feed URL when an exception is raised' do
      mock(Feedjira).parse(anything) { raise StandardError.new("Some error!") }
      expect {
        agent.check
      }.not_to raise_error
      expect(agent.logs.last.message).to match(%r[Failed to fetch https://github.com])
    end
  end
end
