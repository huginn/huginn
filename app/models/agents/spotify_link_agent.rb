require 'rspotify'

module Agents
  class SpotifyLinkAgent < Agent
    cannot_be_scheduled!

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload.dup
        artist_link = get_spotify_link(payload[:artist_name])
        payload[:artist_link] = artist_link if artist_link
        create_event(payload: payload)
      end
    end

    def working?
      true
    end

    private

    def get_spotify_link(artist_name)
      artists = RSpotify::Artist.search(artist_name)
      artists.each do |artist|
        url = artist.external_urls['spotify']
        return url if artist.name.downcase == artist_name.downcase
      end

      nil
    end
  end
end
