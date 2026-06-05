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
export default {
  mounted() {
    this.objectUrl = null

    this.onChange = (event) => {
      const file = event.target.files && event.target.files[0]
      if (file) this.setFile(file)
    }

    this.onDrop = (event) => {
      const file = event.dataTransfer && event.dataTransfer.files && event.dataTransfer.files[0]
      if (file) this.setFile(file)
    }

    const input = this.el.querySelector("input[type=file]")
    if (input) input.addEventListener("change", this.onChange)
    this.fileInput = input

    // Capture phase so we read the dropped file before LiveView handles the
    // drop and starts its own upload.
    this.el.addEventListener("drop", this.onDrop, true)

    this.applyPreview()
  },

  updated() {
    this.applyPreview()
  },

  destroyed() {
    if (this.fileInput) this.fileInput.removeEventListener("change", this.onChange)
    this.el.removeEventListener("drop", this.onDrop, true)
    this.revoke()
  },

  setFile(file) {
    this.revoke()
    this.objectUrl = URL.createObjectURL(file)
    this.applyPreview()
  },

  applyPreview() {
    const img = this.el.querySelector("img[data-role=client-preview]")
    if (img && this.objectUrl && img.src !== this.objectUrl) {
      img.src = this.objectUrl
    }
  },

  revoke() {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }
  },
}
