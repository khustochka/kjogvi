// Hook for the search input inside Autocomplete.
//
// Phoenix LiveView's `phx-hook` attribute holds a single name (no
// space-separated stacking), so this hook covers everything needed by
// the full autocomplete picker. Standalone search inputs (no dropdown)
// use the smaller `SearchInput` hook instead.
//
// Pushes the following events to the input's `phx-target`:
//
//   - "nav"                {direction: "up" | "down"} on ArrowUp/ArrowDown
//   - "nav_select"         on Enter or Tab (commits the highlighted result)
//   - "abandon"            on Escape (revert the field; selection unchanged)
//   - "highlight_result"   {index} on mouseover over a result row
//   - "focus"              when the input regains focus (reopens dropdown)
//
// The custom × button on `SearchInput` and any keyup-flushed empty
// value go through `phx-keyup` (configured `on_search`/`on_clear`) and
// the server's `search`/`clear` handlers — this hook does not push
// `clear` itself.
//
// Also listens for a server-pushed event named `${id}:highlight` and
// scrolls the matching result into view.
const navKeys = new Set(["ArrowDown", "ArrowUp", "Enter", "Escape", "Tab"])

export default {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        // Suppress the browser's native "clear input on Escape" for
        // search inputs. The server-side abandon handler reverts the
        // field via the next render; native clear would fire extra
        // events that race that.
        e.preventDefault()
        this.pushEventTo(this.el, "abandon", {})
      } else if (e.key === "ArrowDown") {
        e.preventDefault()
        this.pushEventTo(this.el, "nav", {direction: "down"})
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        this.pushEventTo(this.el, "nav", {direction: "up"})
      } else if (e.key === "Enter") {
        e.preventDefault()
        this.el.blur()
        this.pushEventTo(this.el, "nav_select", {})
      } else if (e.key === "Tab") {
        // Tab commits and lets the browser advance focus naturally.
        this.pushEventTo(this.el, "nav_select", {})
      }
    })

    // Stop nav keys from bubbling — outer elements may bind their own
    // shortcuts (e.g. `phx-window-keyup`).
    this.el.addEventListener("keyup", (e) => {
      if (navKeys.has(e.key)) e.stopPropagation()
    })

    this.el.addEventListener("focus", () => {
      this.pushEventTo(this.el, "focus", {})
    })

    // Mouseover delegated at the document level so result rows
    // (mounted/unmounted as the dropdown opens and closes) don't each
    // need their own listener. Scoped by id prefix — each Autocomplete
    // names its result rows `${input.id}-result-<n>`, so multiple
    // pickers on a page never cross-fire.
    const prefix = `${this.el.id}-result-`
    this.mouseoverHandler = (e) => {
      const resultEl = e.target.closest("[data-result-index]")
      if (!resultEl || !resultEl.id.startsWith(prefix)) return
      const index = parseInt(resultEl.dataset.resultIndex)
      this.pushEventTo(this.el, "highlight_result", {index})
    }
    document.addEventListener("mouseover", this.mouseoverHandler)

    this.handleEvent(`${this.el.id}:highlight`, ({index}) => {
      const el = document.getElementById(`${this.el.id}-result-${index}`)
      if (el) el.scrollIntoView({block: "nearest"})
    })
  },
  destroyed() {
    if (this.mouseoverHandler) {
      document.removeEventListener("mouseover", this.mouseoverHandler)
    }
  },
}
