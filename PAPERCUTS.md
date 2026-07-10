# Papercuts

Small frictions hit while working — retried tool calls, undocumented setup steps, flaky commands, stale caches, misleading errors, non-obvious gotchas. Append an entry as you hit them (see AGENTS.md → "Log papercuts"). One or two sentences each: what you were doing → what got in the way (a guess at cause/fix is a bonus).

- Testing autocomplete suggestions: asserting `html =~ "Park Site"` on the dropdown fails because `Highlight.highlighted_text` wraps the matched term in `<strong>` (`<strong>Park</strong> Site`). Assert on the un-matched remainder of the name (as form_test does) or query by element id.
