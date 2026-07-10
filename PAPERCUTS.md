# Papercuts

Small frictions hit while working — retried tool calls, undocumented setup steps, flaky commands, stale caches, misleading errors, non-obvious gotchas. Append an entry as you hit them (see AGENTS.md → "Log papercuts"). One or two sentences each: what you were doing → what got in the way (a guess at cause/fix is a bonus).

- Testing autocomplete suggestions: asserting `html =~ "Park Site"` on the dropdown fails because `Highlight.highlighted_text` wraps the matched term in `<strong>` (`<strong>Park</strong> Site`). Assert on the un-matched remainder of the name (as form_test does) or query by element id.
- Running `mix test apps/kjogvi/test/... apps/kjogvi_web/test/...` from the umbrella root silently ran only the kjogvi_web files ("14 passed", no warning that the kjogvi paths were skipped). Run each app's paths from its own directory (`cd apps/kjogvi && mix test test/...`) to be sure they execute.
- Asserting the LiveView error flash: the element id is `#flash-group-error` (the app layout's `flash_group` id-prefixes its flashes), not the `#flash-error` default from `CoreComponents.flash`.
- Adding `{:struct, Kjogvi.Geo.Location}` as a NimbleOptions type in `Location.Filter`'s schema created a compile-time xref cycle (module attribute evaluation makes it a compile dep; Location depends back on Filter via Query), failing `mix lint`. Used `:any` for the field type instead.
- Menu links (e.g. `private_menu.html.heex`) are plain `href` links, so every nav click is a full document reload; in Firefox this flashed the "Connection interrupted" popup because Firefox aborts the websocket at navigation start (mitigated with `disconnectedTimeout` in app.js). Converting same-live_session links to `navigate={...}` would avoid the reload entirely.
