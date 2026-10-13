module LocationMapHelper
  # Head tags for a map of location Events: Google Maps when the Agent has
  # an API key, Leaflet with OpenStreetMap tiles otherwise.
  def location_map_head_tags(api_key)
    tags =
      if api_key.present?
        [javascript_include_tag("https://maps.googleapis.com/maps/api/js?key=#{ERB::Util.url_encode(api_key)}")]
      else
        [stylesheet_link_tag("leaflet"), javascript_include_tag("leaflet")]
      end
    tags << javascript_include_tag("location_map")
    safe_join(tags, "\n")
  end
end
