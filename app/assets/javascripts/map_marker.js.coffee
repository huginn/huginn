window.map_marker = (map, options = {}) ->
  pos = new google.maps.LatLng(options.lat, options.lng)

  if options.radius > 0
    marker = new google.maps.Circle
      map: map
      strokeColor: '#FF0000'
      strokeOpacity: 0.8
      strokeWeight: 2
      fillColor: '#FF0000'
      fillOpacity: 0.35
      center: pos
      radius: options.radius
    return marker
  else if options.course
    p1 = new LatLon(pos.lat(), pos.lng())
    speed = options.speed ? 1
    p2 = p1.destinationPoint(options.course, Math.max(0.2, speed) * 0.1)

    lineCoordinates = [
      pos
      new google.maps.LatLng(p2.lat(), p2.lon())
    ]

    lineSymbol =
      path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW

    arrow = new google.maps.Polyline
      map: map
      path: lineCoordinates
      icons: [
        {
          icon: lineSymbol
          offset: '100%'
        }
      ]
    return arrow
  else
    marker = new google.maps.Marker
      map: map
      position: pos
      title: 'Recorded Location'
    return marker
