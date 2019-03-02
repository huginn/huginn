# encoding: utf-8

require 'rails_helper'

describe Agents::DataOutputAgent do
  let(:agent) do
    _agent = Agents::DataOutputAgent.new(:name => 'My Data Output Agent')
    _agent.options = _agent.default_options.merge('secrets' => ['secret1', 'secret2'], 'events_to_show' => 3)
    _agent.options['template']['item']['pubDate'] = "{{date}}"
    _agent.options['template']['item']['category'] = "{{ category | as_object }}"
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::DataOutputAgent.async_receive agent.id, [events(:bob_website_agent_event).id]
      expect(agent.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(agent.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end

    it "should validate presence and length of secrets" do
      agent.options[:secrets] = ""
      expect(agent).not_to be_valid
      agent.options[:secrets] = "foo"
      expect(agent).not_to be_valid
      agent.options[:secrets] = "foo/bar"
      expect(agent).not_to be_valid
      agent.options[:secrets] = "foo.xml"
      expect(agent).not_to be_valid
      agent.options[:secrets] = false
      expect(agent).not_to be_valid
      agent.options[:secrets] = []
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["foo.xml"]
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["hello", true]
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["hello"]
      expect(agent).to be_valid
      agent.options[:secrets] = ["hello", "world"]
      expect(agent).to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      agent.options[:expected_receive_period_in_days] = ""
      expect(agent).not_to be_valid
      agent.options[:expected_receive_period_in_days] = 0
      expect(agent).not_to be_valid
      agent.options[:expected_receive_period_in_days] = -1
      expect(agent).not_to be_valid
    end

    it "should validate presence of template and template.item" do
      agent.options[:template] = ""
      expect(agent).not_to be_valid
      agent.options[:template] = {}
      expect(agent).not_to be_valid
      agent.options[:template] = { 'item' => 'foo' }
      expect(agent).not_to be_valid
      agent.options[:template] = { 'item' => { 'title' => 'hi' } }
      expect(agent).to be_valid
    end
  end

  describe "#receive" do
    it "should push to hubs when push_hubs is given" do
      agent.options[:push_hubs] = %w[http://push.example.com]
      agent.options[:template] = { 'link' => 'http://huginn.example.org' }

      alist = nil

      stub_request(:post, 'http://push.example.com/')
        .with(headers: { 'Content-Type' => %r{\Aapplication/x-www-form-urlencoded\s*(?:;|\z)} })
        .to_return { |request|
        alist = URI.decode_www_form(request.body).sort
        { status: 200, body: 'ok' }
      }

      agent.receive(events(:bob_website_agent_event))

      expect(alist).to eq [
        ["hub.mode", "publish"],
        ["hub.url", agent.feed_url(secret: agent.options[:secrets].first, format: :xml)]
      ]
    end
  end

  describe "#receive_web_request" do
    before do
      current_time = Time.now
      stub(Time).now { current_time }
      agents(:bob_website_agent).events.destroy_all
    end

    it "requires a valid secret" do
      content, status, content_type = agent.receive_web_request({ 'secret' => 'fake' }, 'get', 'text/xml')
      expect(status).to eq(401)
      expect(content).to eq("Not Authorized")

      content, status, content_type = agent.receive_web_request({ 'secret' => 'fake' }, 'get', 'application/json')
      expect(status).to eq(401)
      expect(content).to eq({ :error => "Not Authorized" })

      content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'application/json')
      expect(status).to eq(200)
    end

    describe "outputting events as RSS and JSON" do
      let!(:event1) do
        agents(:bob_website_agent).create_event :payload => {
          "site_title" => "XKCD",
          "url" => "http://imgs.xkcd.com/comics/evolving.png",
          "title" => "Evolving",
          "hovertext" => "Biologists play reverse Pokemon, trying to avoid putting any one team member on the front lines long enough for the experience to cause evolution.",
          "category" => []
        }
      end

      let!(:event2) do
        agents(:bob_website_agent).create_event :payload => {
          "site_title" => "XKCD",
          "url" => "http://imgs.xkcd.com/comics/evolving2.png",
          "title" => "Evolving again",
          "date" => '',
          "hovertext" => "Something else",
          "category" => ["Category 1", "Category 2"]
        }
      end

      let!(:event3) do
        agents(:bob_website_agent).create_event :payload => {
          "site_title" => "XKCD",
          "url" => "http://imgs.xkcd.com/comics/evolving0.png",
          "title" => "Evolving yet again with a past date",
          "date" => '2014/05/05',
          "hovertext" => "A small text",
          "category" => ["Some category"]
        }
      end

      it "can output RSS" do
        stub(agent).feed_link { "https://yoursite.com" }
        content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
        expect(status).to eq(200)
        expect(content_type).to eq('application/rss+xml')
        expect(content.gsub(/\s+/, '')).to eq Utils.unindent(<<-XML).gsub(/\s+/, '')
          <?xml version="1.0" encoding="UTF-8" ?>
          <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
          <channel>
           <atom:link href="https://yoursite.com/users/#{agent.user.id}/web_requests/#{agent.id}/secret1.xml" rel="self" type="application/rss+xml"/>
           <atom:icon>https://yoursite.com/favicon.ico</atom:icon>
           <title>XKCD comics as a feed</title>
           <description>This is a feed of recent XKCD comics, generated by Huginn</description>
           <link>https://yoursite.com</link>
           <lastBuildDate>#{Time.now.rfc2822}</lastBuildDate>
           <pubDate>#{Time.now.rfc2822}</pubDate>
           <ttl>60</ttl>

           <item>
            <title>Evolving yet again with a past date</title>
            <description>Secret hovertext: A small text</description>
            <link>http://imgs.xkcd.com/comics/evolving0.png</link>
            <pubDate>#{Time.zone.parse(event3.payload['date']).rfc2822}</pubDate>
            <category>Some category</category>
            <guid isPermaLink="false">#{event3.id}</guid>
           </item>

           <item>
            <title>Evolving again</title>
            <description>Secret hovertext: Something else</description>
            <link>http://imgs.xkcd.com/comics/evolving2.png</link>
            <pubDate>#{event2.created_at.rfc2822}</pubDate>
            <category>Category 1</category>
            <category>Category 2</category>
            <guid isPermaLink="false">#{event2.id}</guid>
           </item>

           <item>
            <title>Evolving</title>
            <description>Secret hovertext: Biologists play reverse Pokemon, trying to avoid putting any one team member on the front lines long enough for the experience to cause evolution.</description>
            <link>http://imgs.xkcd.com/comics/evolving.png</link>
            <pubDate>#{event1.created_at.rfc2822}</pubDate>
            <guid isPermaLink="false">#{event1.id}</guid>
           </item>

          </channel>
          </rss>
        XML
      end

      describe "with custom rss_content_type given" do
        before do
          agent.options['rss_content_type'] = 'text/xml'
          agent.save!
        end

        it "can output RSS with the Content-Type" do
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('text/xml')
        end
      end

      it "can output RSS with hub links when push_hubs is specified" do
        stub(agent).feed_link { "https://yoursite.com" }
        agent.options[:push_hubs] = %w[https://pubsubhubbub.superfeedr.com/ https://pubsubhubbub.appspot.com/]
        content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
        expect(status).to eq(200)
        expect(content_type).to eq('application/rss+xml')
        xml = Nokogiri::XML(content)
        expect(xml.xpath('/rss/channel/atom:link[@rel="hub"]/@href').map(&:text).sort).to eq agent.options[:push_hubs].sort
      end

      it "can output JSON" do
        agent.options['template']['item']['foo'] = "hi"

        content, status, content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
        expect(status).to eq(200)

        expect(content).to eq({
          'title' => 'XKCD comics as a feed',
          'description' => 'This is a feed of recent XKCD comics, generated by Huginn',
          'pubDate' => Time.now,
          'items' => [
            {
              'title' => 'Evolving yet again with a past date',
              'description' => 'Secret hovertext: A small text',
              'link' => 'http://imgs.xkcd.com/comics/evolving0.png',
              'guid' => {"contents" => event3.id, "isPermaLink" => "false"},
              'pubDate' => Time.zone.parse(event3.payload['date']).rfc2822,
              'category' => ['Some category'],
              'foo' => 'hi'
            },
            {
              'title' => 'Evolving again',
              'description' => 'Secret hovertext: Something else',
              'link' => 'http://imgs.xkcd.com/comics/evolving2.png',
              'guid' => {"contents" => event2.id, "isPermaLink" => "false"},
              'pubDate' => event2.created_at.rfc2822,
              'category' => ['Category 1', 'Category 2'],
              'foo' => 'hi'
            },
            {
              'title' => 'Evolving',
              'description' => 'Secret hovertext: Biologists play reverse Pokemon, trying to avoid putting any one team member on the front lines long enough for the experience to cause evolution.',
              'link' => 'http://imgs.xkcd.com/comics/evolving.png',
              'guid' => {"contents" => event1.id, "isPermaLink" => "false"},
              'pubDate' => event1.created_at.rfc2822,
              'category' => [],
              'foo' => 'hi'
            }
          ]
        })
      end

      describe "with custom response_headers given" do
        before do
          agent.options['response_headers'] = {"Access-Control-Allow-Origin" => "*", "X-My-Custom-Header" => "hello"}
          agent.save!
        end

        it "can respond with custom headers" do
          content, status, content_type, response_headers = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(response_headers).to eq({"Access-Control-Allow-Origin" => "*", "X-My-Custom-Header" => "hello"})
        end
      end

      context 'with more events' do
        let!(:event4) do
          agents(:bob_website_agent).create_event payload: {
            'site_title' => 'XKCD',
            'url' => 'http://imgs.xkcd.com/comics/comic1.png',
            'title' => 'Comic 1',
            'date' => '',
            'hovertext' => 'Hovertext for Comic 1'
          }
        end

        let!(:event5) do
          agents(:bob_website_agent).create_event payload: {
            'site_title' => 'XKCD',
            'url' => 'http://imgs.xkcd.com/comics/comic2.png',
            'title' => 'Comic 2',
            'date' => '',
            'hovertext' => 'Hovertext for Comic 2'
          }
        end

        let!(:event6) do
          agents(:bob_website_agent).create_event payload: {
            'site_title' => 'XKCD',
            'url' => 'http://imgs.xkcd.com/comics/comic3.png',
            'title' => 'Comic 3',
            'date' => '',
            'hovertext' => 'Hovertext for Comic 3'
          }
        end

        describe 'limiting' do
          it 'can select the last `events_to_show` events' do
            agent.options['events_to_show'] = 2
            content, _status, _content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
            expect(content['items'].map {|i| i["title"] }).to eq(["Comic 3", "Comic 2"])
          end
        end
      end

      describe 'ordering' do
        before do
          agent.options['events_order'] = ['{{hovertext}}']
          agent.options['events_list_order'] = ['{{title}}']
        end

        it 'can reorder the last `events_to_show` events based on a Liquid expression' do
          agent.options['events_to_show'] = 2
          asc_content, _status, _content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
          expect(asc_content['items'].map {|i| i["title"] }).to eq(["Evolving", "Evolving again"])

          agent.options['events_to_show'] = 40
          asc_content, _status, _content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
          expect(asc_content['items'].map {|i| i["title"] }).to eq(["Evolving", "Evolving again", "Evolving yet again with a past date"])

          agent.options['events_list_order'] = [['{{title}}', 'string', true]]

          desc_content, _status, _content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
          expect(desc_content['items']).to eq(asc_content['items'].reverse)
        end
      end

      describe "interpolating \"events\"" do
        before do
          agent.options['template']['title'] = "XKCD comics as a feed{% if events.first.site_title %} ({{events.first.site_title}}){% endif %}"
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')
          expect(Nokogiri(content).at('/rss/channel/title/text()').text).to eq('XKCD comics as a feed (XKCD)')
        end

        it "can output JSON" do
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
          expect(status).to eq(200)

          expect(content['title']).to eq('XKCD comics as a feed (XKCD)')
        end

        context "with event with \"events\"" do
          before do
            agent.sources.first.create_event payload: {
              'site_title' => 'XKCD',
              'url' => 'http://imgs.xkcd.com/comics/comicX.png',
              'title' => 'Comic X',
              'date' => '',
              'hovertext' => 'Hovertext for Comic X',
              'events' => 'Events!'
            }
            agent.options['template']['item']['events_data'] = "{{ events }}"
            agent.save!
          end

          it "can access the value without being overridden" do
            content, status, content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
            expect(status).to eq(200)

            expect(content['items'].first['events_data']).to eq('Events!')
          end
        end
      end

      describe "with a specified icon" do
        before do
          agent.options['template']['icon'] = 'https://somesite.com/icon.png'
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')
          expect(Nokogiri(content).at('/rss/channel/atom:icon/text()').text).to eq('https://somesite.com/icon.png')
        end
      end

      describe "with media namespace not set" do
        before do
          agent.options['ns_media'] = nil
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')

          doc = Nokogiri(content)
          namespaces = doc.collect_namespaces
          expect(namespaces).not_to include("xmlns:media")
        end
      end

      describe "with media namespace set true" do
        before do
          agent.options['ns_media'] = 'true'
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')

          doc = Nokogiri(content)
          namespaces = doc.collect_namespaces
          expect(namespaces).to include(
            "xmlns:media" => 'http://search.yahoo.com/mrss/'
          )
        end
      end

      describe "with media namespace set false" do
        before do
          agent.options['ns_media'] = 'false'
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')

          doc = Nokogiri(content)
          namespaces = doc.collect_namespaces
          expect(namespaces).not_to include("xmlns:media")
        end
      end

      describe "with itunes namespace not set" do
        before do
          agent.options['ns_itunes'] = nil
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')
          
          doc = Nokogiri(content)
          namespaces = doc.collect_namespaces
          expect(namespaces).not_to include("xmlns:itunes")
          expect(doc.at("/rss/channel/*[local-name()='itunes:image']")).to be_nil
        end
      end

      describe "with itunes namespace set true" do
        before do
          agent.options['ns_itunes'] = 'true'
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')
          
          doc = Nokogiri(content)
          namespaces = doc.collect_namespaces
          expect(namespaces).to include(
            "xmlns:itunes" => 'http://www.itunes.com/dtds/podcast-1.0.dtd'
          )
          expect(doc.at('/rss/channel/itunes:image').attr('href')).to eq('https://yoursite.com/favicon.ico')          
        end
      end

      describe "with itunes namespace set false" do
        before do
          agent.options['ns_itunes'] = 'false'
          agent.save!
        end

        it "can output RSS" do
          stub(agent).feed_link { "https://yoursite.com" }
          content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
          expect(status).to eq(200)
          expect(content_type).to eq('application/rss+xml')

          doc = Nokogiri(content)
          namespaces = doc.collect_namespaces
          expect(namespaces).not_to include("xmlns:itunes")
        end
      end
    end

    describe "outputting nesting" do
      before do
        agent.options['template']['item']['enclosure'] = {
          "_attributes" => {
            "type" => "audio/mpeg",
            "url" => "{{media_url}}"
          }
        }
        agent.options['template']['item']['foo'] = {
          "_attributes" => {
            "attr" => "attr-value-{{foo}}"
          },
          "_contents" => "Foo: {{foo}}"
        }
        agent.options['template']['item']['nested'] = {
          "_attributes" => {
            "key" => "value"
          },
          "_contents" => {
            "title" => "some title"
          }
        }
        agent.options['template']['item']['simpleNested'] = {
          "title" => "some title",
          "complex" => {
            "_attributes" => {
              "key" => "value"
            },
            "_contents" => {
              "first" => {
                "_attributes" => {
                  "a" => "b"
                },
                "_contents" => {
                  "second" => "value"
                }
              }
            }
          }
        }
        agent.save!
      end

      let!(:event) do
        agents(:bob_website_agent).create_event :payload => {
          "url" => "http://imgs.xkcd.com/comics/evolving.png",
          "title" => "Evolving",
          "hovertext" => "Biologists play reverse Pokemon, trying to avoid putting any one team member on the front lines long enough for the experience to cause evolution.",
          "media_url" => "http://google.com/audio.mpeg",
          "category" => ["Category 1", "Category 2"],
          "foo" => 1
        }
      end

      it "can output JSON" do
        content, status, content_type = agent.receive_web_request({ 'secret' => 'secret2' }, 'get', 'application/json')
        expect(status).to eq(200)
        expect(content['items'].first).to eq(
          {
            'title' => 'Evolving',
            'description' => 'Secret hovertext: Biologists play reverse Pokemon, trying to avoid putting any one team member on the front lines long enough for the experience to cause evolution.',
            'link' => 'http://imgs.xkcd.com/comics/evolving.png',
            'guid' => {"contents" => event.id, "isPermaLink" => "false"},
            'pubDate' => event.created_at.rfc2822,
            'category' => ['Category 1', 'Category 2'],
            'enclosure' => {
              "type" => "audio/mpeg",
              "url" => "http://google.com/audio.mpeg"
            },
            'foo' => {
              'attr' => 'attr-value-1',
              'contents' => 'Foo: 1'
            },
            'nested' => {
              "key" => "value",
              "title" => "some title"
            },
            'simpleNested' => {
              "title" => "some title",
              "complex" => {
                "key"=>"value",
                "first" => {
                  "a" => "b",
                  "second"=>"value"
                }
              }
            }
          }
        )
      end

      it "can output RSS" do
        stub(agent).feed_link { "https://yoursite.com" }
        content, status, content_type = agent.receive_web_request({ 'secret' => 'secret1' }, 'get', 'text/xml')
        expect(status).to eq(200)
        expect(content_type).to eq('application/rss+xml')
        expect(content.gsub(/\s+/, '')).to eq Utils.unindent(<<-XML).gsub(/\s+/, '')
          <?xml version="1.0" encoding="UTF-8" ?>
          <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/" >
          <channel>
           <atom:link href="https://yoursite.com/users/#{agent.user.id}/web_requests/#{agent.id}/secret1.xml" rel="self" type="application/rss+xml"/>
           <atom:icon>https://yoursite.com/favicon.ico</atom:icon>
           <title>XKCD comics as a feed</title>
           <description>This is a feed of recent XKCD comics, generated by Huginn</description>
           <link>https://yoursite.com</link>
           <lastBuildDate>#{Time.now.rfc2822}</lastBuildDate>
           <pubDate>#{Time.now.rfc2822}</pubDate>
           <ttl>60</ttl>

           <item>
             <title>Evolving</title>
             <description>Secret hovertext: Biologists play reverse Pokemon, trying to avoid putting any one team member on the front lines long enough for the experience to cause evolution.</description>
             <link>http://imgs.xkcd.com/comics/evolving.png</link>
             <pubDate>#{event.created_at.rfc2822}</pubDate>
             <category>Category 1</category>
             <category>Category 2</category>
             <enclosure type="audio/mpeg" url="http://google.com/audio.mpeg" />
             <foo attr="attr-value-1">Foo: 1</foo>
             <nested key="value"><title>some title</title></nested>
             <simpleNested>
               <title>some title</title>
               <complex key="value">
                 <first a="b">
                   <second>value</second>
                 </first>
               </complex>
             </simpleNested>
             <guid isPermaLink="false">#{event.id}</guid>
           </item>

          </channel>
          </rss>
        XML
      end
    end
  end
end
