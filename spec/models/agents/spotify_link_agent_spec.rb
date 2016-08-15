require 'rails_helper'

describe Agents::SpotifyLinkAgent do
  before(:each) do
    @agent = Agents::SpotifyLinkAgent.new
    @agent.name = 'Spotify linker'
    @agent.user = users(:bob)
    @agent.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
  end

  describe '#receive' do
    context 'when the event payload contains artist_name' do
      it 'adds an artist link to the payload' do
        @event.payload = { artist_name: 'Test artist' }

        artist_options = {
          'name' => 'Test artist',
          'external_urls' => {
            'spotify' => 'http://open.spotify.com/test_artist'
          }
        }
        artist = RSpotify::Artist.new(artist_options)
        mock(RSpotify::Artist).search(anything) { [artist] }

        @agent.receive([@event])
        last_payload = Event.last.payload['spotify_link']
        expect(last_payload)
          .to(eq('http://open.spotify.com/test_artist'))
      end
    end

    context 'when the event payload contains track_name' do
      it 'adds a track link to the payload' do
        @event.payload = {
          artist_name: 'Test artist',
          track_name: 'Test track'
        }

        track_options = {
          'name' => 'Test track',
          'external_urls' => {
            'spotify' => 'http://open.spotify.com/test_track'
          }
        }
        track = RSpotify::Track.new(track_options)
        mock(RSpotify::Track).search(anything) { [track] }

        @agent.receive([@event])
        last_payload = Event.last.payload['spotify_link']
        expect(last_payload)
          .to(eq('http://open.spotify.com/test_track'))
      end
    end
  end
end
