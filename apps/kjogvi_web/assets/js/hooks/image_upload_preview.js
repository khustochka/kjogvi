// Client-side preview for the add-image upload.
//
// The add-image flow consumes the upload as soon as it finishes (so the
// server can read the file's EXIF date before saving). Consuming empties
// LiveView's `@upload.entries`, which removes the built-in
// `live_img_preview`. But the browser still holds the picked `File`, so this
// hook keeps showing it without any server round-trip:
//
//   1. As the user picks a file (file dialog) or drops one, capture the
//      `File` and build a `blob:` object URL from it.
//   2. The drop zone renders a `<img data-role="client-preview">` once the
//      server flips `uploaded?`; on every patch we (re)apply the object URL
//      to it, so the preview survives the consume-induced re-render.
//
// The object URL is revoked when a new file replaces it and on destroy, so
// we don't leak blob references.
//
// Placed on the stable drop-zone container (not the `<img>`, which only
// exists post-upload), so the hook persists across the patch that adds it.
//
// Two subtleties this hook has to defend against, both of which otherwise
// produce a stale preview (old image shown, but the server already has the
// new file's data):
//
//   * LiveView may replace the `<input type=file>` element on a patch (the
//     surrounding markup changes when `uploaded?` flips). A `change`
//     listener bound only in `mounted()` would then be attached to a
//     detached node, and picking a new file would never reach `setFile`.
//     So we (re)bind the listener to whatever input is current on every
//     update.
//   * On a LiveView reconnect the hook is re-mounted with a fresh, empty
//     `objectUrl`, while the previously rendered `<img>` may still carry a
//     leftover `blob:` src in the DOM. We clear any such stale src so the
//     old image can't linger under a new upload.
export default {
  mounted() {
    this.objectUrl = null
    this.boundInput = null

    this.onChange = (event) => {
      const file = event.target.files && event.target.files[0]
      if (file) this.setFile(file)
    }

    this.onDrop = (event) => {
      const file = event.dataTransfer && event.dataTransfer.files && event.dataTransfer.files[0]
      if (file) this.setFile(file)
    }

    // Capture phase so we read the dropped file before LiveView handles the
    // drop and starts its own upload.
    this.el.addEventListener("drop", this.onDrop, true)

    // A re-mount (e.g. after reconnect) starts with no objectUrl, but the
    // server-rendered `<img>` may still hold a blob src from before. Drop it
    // so a stale preview can't survive the reconnect.
    this.clearStalePreview()

    this.bindInput()
    this.applyPreview()
  },

  updated() {
    // The input may have been replaced by the patch; rebind if so.
    this.bindInput()
    this.applyPreview()
  },

  destroyed() {
    this.unbindInput()
    this.el.removeEventListener("drop", this.onDrop, true)
    this.revoke()
  },

  bindInput() {
    const input = this.el.querySelector("input[type=file]")
    if (input === this.boundInput) return

    this.unbindInput()
    if (input) {
      input.addEventListener("change", this.onChange)
      this.boundInput = input

      // If a fresh input already carries a file (the change event fired on the
      // old, now-replaced element, or before we rebound), adopt it so the
      // latest picked file always wins over a previously stashed one.
      const file = input.files && input.files[0]
      if (file) this.setFile(file)
    }
  },

  unbindInput() {
    if (this.boundInput) {
      this.boundInput.removeEventListener("change", this.onChange)
      this.boundInput = null
    }
  },

  setFile(file) {
    this.revoke()
    this.objectUrl = URL.createObjectURL(file)
    this.applyPreview()
  },

  applyPreview() {
    const img = this.el.querySelector("img[data-role=client-preview]")
    if (!img) return

    if (this.objectUrl) {
      if (img.src !== this.objectUrl) img.src = this.objectUrl
    } else if (img.src) {
      // No file held by this hook instance but the `<img>` still has a src
      // (a leftover blob from a prior life): clear it rather than show stale.
      img.removeAttribute("src")
    }
  },

  // Drop a blob src left on the preview `<img>` by a previous hook life.
  clearStalePreview() {
    const img = this.el.querySelector("img[data-role=client-preview]")
    if (img && img.src) img.removeAttribute("src")
  },

  revoke() {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }
  },
}
