require 'rails_helper'

describe Agents::SpotifyLinkAgent do
  describe '#receive' do
    it 'adds an artist_link field to the event payload' do
      agent = Agents::SpotifyLinkAgent.new
      agent.name = 'Spotify linker'
      agent.user = users(:bob)
      agent.save!

      event = Event.new
      event.agent = agents(:bob_weather_agent)
      event.payload = { artist_name: 'Test artist' }

      artist_options = {
        'name' => 'Test artist',
        'external_urls' => {
          'spotify' => 'http://open.spotify.com/test_artist'
        }
      }
      artist = RSpotify::Artist.new(artist_options)
      mock(RSpotify::Artist).search('Test artist') { [artist] }

      agent.receive([event])
      last_payload = Event.last.payload['artist_link']
      expect(last_payload)
        .to(eq('http://open.spotify.com/test_artist'))
    end
  end
end
