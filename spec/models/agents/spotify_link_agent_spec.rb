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
      it 'adds an artist_link field to the event payload' do
        @event.payload = { artist_name: 'Test artist' }

        artist_options = {
          'name' => 'Test artist',
          'external_urls' => {
            'spotify' => 'http://open.spotify.com/test_artist'
          }
        }
        artist = RSpotify::Artist.new(artist_options)
        mock(RSpotify::Artist).search('Test artist') { [artist] }

        @agent.receive([@event])
        last_payload = Event.last.payload['artist_link']
        expect(last_payload)
          .to(eq('http://open.spotify.com/test_artist'))
      end
    end

    context 'when the event payload contains artist_name and track_name' do
      it 'adds a track_link to the event payload' do
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
        last_payload = Event.last.payload['track_link']
        expect(last_payload)
          .to(eq('http://open.spotify.com/test_track'))
      end
    end
  end
end
