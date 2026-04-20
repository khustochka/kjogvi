import {Loader} from "@googlemaps/js-api-loader"

let loaderPromise = null

function loadGoogleMaps() {
  if (!loaderPromise) {
    const apiKey = document.querySelector("meta[name='google-maps-api-key']")?.content
    if (!apiKey) {
      return Promise.reject(new Error("Missing google-maps-api-key meta tag"))
    }
    const loader = new Loader({apiKey, version: "weekly"})
    loaderPromise = loader.importLibrary("maps").then(async (maps) => {
      const {Marker} = await loader.importLibrary("marker")
      return {maps, Marker}
    })
  }
  return loaderPromise
}

export default {
  mounted() {
    this.destroyed_ = false
    const {lat, lon, parentLat, parentLon} = this.readCoords()

    let center, zoom
    if (lat !== null && lon !== null) {
      center = {lat, lng: lon}
      zoom = 10
    } else if (parentLat !== null && parentLon !== null) {
      center = {lat: parentLat, lng: parentLon}
      zoom = 10
    } else {
      center = {lat: 20, lng: 0}
      zoom = 2
    }

    this.lastLat = lat
    this.lastLon = lon
    this.lastParentLat = parentLat
    this.lastParentLon = parentLon

    loadGoogleMaps()
      .then(({maps, Marker}) => {
        if (this.destroyed_) return
        const canvas = this.el.querySelector("#location-map-picker-canvas")
        this.Marker = Marker
        this.map = new maps.Map(canvas, {
          center,
          zoom,
          mapTypeId: "hybrid",
          gestureHandling: "greedy",
          mapTypeControl: true,
          streetViewControl: false,
          fullscreenControl: true,
          panControl: false,
          rotateControl: false,
          scaleControl: false,
        })

        const latest = this.readCoords()
        if (latest.lat !== null && latest.lon !== null) {
          this.placeMarker(latest.lat, latest.lon)
        }

        this.map.addListener("click", (e) => {
          const lat = e.latLng.lat()
          const lng = e.latLng.lng()
          this.placeMarker(lat, lng)
          this.suppressPan = true
          this.pushEvent("map_picked", {lat: lat.toFixed(6), lon: lng.toFixed(6)})
        })
      })
      .catch((err) => console.error("Google Maps failed to load", err))
  },

  updated() {
    if (!this.map) return
    const {lat, lon, parentLat, parentLon} = this.readCoords()
    const coordsChanged = lat !== this.lastLat || lon !== this.lastLon
    const parentChanged = parentLat !== this.lastParentLat || parentLon !== this.lastParentLon

    if (coordsChanged) {
      if (lat !== null && lon !== null) {
        this.placeMarker(lat, lon)
        if (!this.suppressPan) {
          const c = this.map.getCenter()
          if (Math.abs(c.lat() - lat) > 0.5 || Math.abs(c.lng() - lon) > 0.5) {
            this.map.setCenter({lat, lng: lon})
            this.map.setZoom(Math.max(this.map.getZoom(), 8))
          }
        }
      } else {
        this.clearMarker()
      }
    } else if (parentChanged && lat === null && parentLat !== null && parentLon !== null) {
      this.map.setCenter({lat: parentLat, lng: parentLon})
      this.map.setZoom(10)
    }

    this.lastLat = lat
    this.lastLon = lon
    this.lastParentLat = parentLat
    this.lastParentLon = parentLon
    this.suppressPan = false
  },

  readCoords() {
    const parse = (v) => (v === "" || v === undefined ? null : parseFloat(v))
    return {
      lat: parse(this.el.dataset.lat),
      lon: parse(this.el.dataset.lon),
      parentLat: parse(this.el.dataset.parentLat),
      parentLon: parse(this.el.dataset.parentLon),
    }
  },

  placeMarker(lat, lon) {
    const pos = {lat, lng: lon}
    if (this.marker) {
      this.marker.setPosition(pos)
    } else {
      this.marker = new this.Marker({
        position: pos,
        map: this.map,
        draggable: true,
      })
      this.marker.addListener("dragend", (e) => {
        const lat = e.latLng.lat()
        const lng = e.latLng.lng()
        this.suppressPan = true
        this.pushEvent("map_picked", {lat: lat.toFixed(6), lon: lng.toFixed(6)})
      })
    }
  },

  clearMarker() {
    if (this.marker) {
      this.marker.setMap(null)
      this.marker = null
    }
  },

  destroyed() {
    this.destroyed_ = true
    this.clearMarker()
    this.map = null
  },
}
