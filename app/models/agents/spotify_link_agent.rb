require 'rspotify'

module Agents
  class SpotifyLinkAgent < Agent
    cannot_be_scheduled!

    def receive(incoming_events)
      incoming_events.each do |e|
        payload = e.payload.dup
        artist_link = get_spotify_link(e.payload[:artist_name])
        payload[:artist_link] = artist_link unless artist_link.empty?
        create_event(payload: payload)
      end
    end

    def working?
      true
    end

    private

    def get_spotify_link(artist_name)
      artists = RSpotify::Artist.search(artist_name)
      artists.each do |a|
        return a.external_urls['spotify'] if a.name.downcase == artist_name.downcase
      end

      ''
    end
  end
end
