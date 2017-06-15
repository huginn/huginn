module Agents
  class StubhubAgent < Agent
    cannot_receive_events!

    description <<-MD
      The StubHub Agent creates an event for a given StubHub Event.

      It can be used to track how many tickets are available for the event and the minimum and maximum price. All that is required is that you paste in the url from the actual event, e.g. https://www.stubhub.com/outside-lands-music-festival-tickets/outside-lands-music-festival-3-day-pass-san-francisco-golden-gate-park-polo-fields-8-8-2014-9020701/
    MD

    event_description <<-MD
      Events looks like this:
        {
          "url": "https://stubhub.com/valid-event-url"
          "name": "Event Name"
          "date": "2014-08-01"
          "max_price": "999.99"
          "min_price": "100.99"
          "total_postings": "50"
          "total_tickets": "150"
          "venue_name": "Venue Name"
        }
    MD

    default_schedule "every_1d"

    def working?
      event_created_within?(1) && !recent_error_logs?
    end

    def default_options
      { 'url' =>  'https://stubhub.com/enter-your-event-here' }
    end

    def validate_options
      errors.add(:base, 'url is required') unless options['url'].present?
    end

    def url
      interpolated['url']
    end

    def check
      create_event :payload => fetch_stubhub_data(url)
    end

    def fetch_stubhub_data(url)
      StubhubFetcher.call(url)
    end

    class StubhubFetcher

      def self.call(url)
        new(url).fields
      end

      def initialize(url)
        @url = url
      end

      def event_id
        /(\d*)\/{0,1}\z/.match(url)[1]
      end

      def base_url
       'https://www.stubhub.com/listingCatalog/select/?q='
      end

      def build_url
        base_url + "%2B+stubhubDocumentType%3Aevent%0D%0A%2B+event_id%3A#{event_id}%0D%0A&start=0&rows=10&wt=json"
      end

      def response
        uri = URI(build_url)
        Net::HTTP.get(uri)
      end

      def parse_response
        JSON.parse(response)
      end

      def fields
        stubhub_fields = parse_response['response']['docs'][0]
        {
          'url' => url,
          'name' => stubhub_fields['seo_description_en_US'],
          'date' => stubhub_fields['event_date_local'],
          'max_price' => stubhub_fields['maxPrice'].to_s,
          'min_price' => stubhub_fields['minPrice'].to_s,
          'total_postings' => stubhub_fields['totalPostings'].to_s,
          'total_tickets' => stubhub_fields['totalTickets'].to_i.to_s,
          'venue_name' => stubhub_fields['venue_name']
        }
      end

      private

      attr_reader :url

    end
  end
end
