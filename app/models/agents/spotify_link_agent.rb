require 'rspotify'

module Agents
  class SpotifyLinkAgent < Agent
    cannot_be_scheduled!

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = event.payload.dup
        spotify_link = get_spotify_link(payload)
        payload[:spotify_link] = spotify_link if spotify_link

        create_event(payload: payload)
      end
    end

    def working?
      true
    end

    private

    def get_spotify_link(payload)
      if payload[:artist_name] && payload[:track_name]
        get_track_link(payload[:artist_name], payload[:track_name])
      elsif payload[:artist_name]
        get_artist_link(payload[:artist_name])
      end
    end

    def get_artist_link(artist_name)
      artists = RSpotify::Artist.search(artist_name)
      artists.each do |artist|
        url = artist.external_urls['spotify']
        return url if artist.name.downcase == artist_name.downcase
      end

      nil
    end

    def get_track_link(artist_name, track_name)
      query = "#{track_name} artist:#{artist_name}"
      tracks = RSpotify::Track.search(query)
      unless tracks.empty?
        track = tracks.first
        url = track.external_urls['spotify']
        url
      end
    end
  end
end
