// Draws location Events on a map.  Google Maps is used when its API has
// been loaded, which happens when the Agent has an `api_key`; otherwise
// Leaflet with OpenStreetMap tiles is used.
//
//   const map = LocationMap.create(element, { lat, lng }, 15);
//   const overlay = map.addLocation({ lat, lng, radius, course, speed });
//   overlay.hide(); overlay.show();
//   map.fitTo(locations);  // zoom out so that all of them are visible
window.LocationMap = (function () {
  const RED = "#FF0000";

  // The point a short distance ahead of `loc` in the direction of travel.
  function arrowEnd(loc) {
    const p1 = new LatLon(loc.lat, loc.lng);
    const speed = loc.speed != null ? loc.speed : 1;
    const p2 = p1.destinationPoint(loc.course, Math.max(0.2, speed) * 0.1);
    return { lat: p2.lat(), lng: p2.lon() };
  }

  class GoogleMap {
    constructor(element, center, zoom) {
      this.map = new google.maps.Map(element, {
        center: new google.maps.LatLng(center.lat, center.lng),
        zoom,
        mapTypeId: google.maps.MapTypeId.ROADMAP,
      });
    }

    addLocation(loc) {
      const pos = new google.maps.LatLng(loc.lat, loc.lng);
      let overlay;
      if (loc.radius > 0) {
        overlay = new google.maps.Circle({
          strokeColor: RED,
          strokeOpacity: 0.8,
          strokeWeight: 2,
          fillColor: RED,
          fillOpacity: 0.35,
          center: pos,
          radius: loc.radius,
        });
      } else if (loc.course) {
        const end = arrowEnd(loc);
        overlay = new google.maps.Polyline({
          path: [pos, new google.maps.LatLng(end.lat, end.lng)],
          icons: [{ icon: { path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW }, offset: "100%" }],
        });
      } else {
        overlay = new google.maps.Marker({ position: pos, title: "Recorded Location" });
      }
      overlay.setMap(this.map);
      return {
        show: () => overlay.setMap(this.map),
        hide: () => overlay.setMap(null),
      };
    }

    fitTo(locations) {
      const bounds = new google.maps.LatLngBounds();
      locations.forEach((loc) => bounds.extend(new google.maps.LatLng(loc.lat, loc.lng)));
      this.map.fitBounds(bounds);
    }
  }

  class LeafletMap {
    constructor(element, center, zoom) {
      this.map = L.map(element).setView([center.lat, center.lng], zoom);
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      }).addTo(this.map);
    }

    addLocation(loc) {
      const pos = [loc.lat, loc.lng];
      let layer;
      if (loc.radius > 0) {
        layer = L.circle(pos, {
          radius: loc.radius,
          color: RED,
          opacity: 0.8,
          weight: 2,
          fillColor: RED,
          fillOpacity: 0.35,
        });
      } else if (loc.course) {
        const end = arrowEnd(loc);
        const arrow = L.divIcon({
          className: "",
          iconSize: [16, 16],
          iconAnchor: [8, 8],
          html: `<span style="display:inline-block;font-size:16px;line-height:16px;transform:rotate(${loc.course - 90}deg)">&#10148;</span>`,
        });
        layer = L.layerGroup([
          L.polyline([pos, [end.lat, end.lng]], { color: "#000000", weight: 2 }),
          L.marker([end.lat, end.lng], { icon: arrow, interactive: false }),
        ]);
      } else {
        layer = L.circleMarker(pos, { radius: 6, color: "#B00000", fillColor: RED, fillOpacity: 0.9 });
        layer.bindTooltip("Recorded Location");
      }
      layer.addTo(this.map);
      return {
        show: () => layer.addTo(this.map),
        hide: () => layer.remove(),
      };
    }

    fitTo(locations) {
      const bounds = L.latLngBounds(locations.map((loc) => [loc.lat, loc.lng]));
      this.map.fitBounds(bounds, { padding: [20, 20], maxZoom: 15 });
    }
  }

  return {
    create(element, center, zoom = 15) {
      const Map = window.google && google.maps ? GoogleMap : LeafletMap;
      return new Map(element, center, zoom);
    },
  };
})();
