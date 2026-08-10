# TODO

Items identified during a `/simplify` pass over the last 30 days of commits
(hardening effort) but deliberately not auto-fixed because they'd change
behavior or need a broader refactor than a cleanup pass should make.

## Reuse

- **`BrowserDiscovery` reinvents Ferrum's own binary detection**
  (`lib/lookbook_visual_tester/browser_discovery.rb`). Ferrum's
  `Ferrum::Browser::Command` already resolves a browser via
  `options.browser_path || ENV["BROWSER_PATH"] || defaults.detect_path`, and
  `detect_path` searches `PATH` per-platform. Our module exists specifically
  to _avoid_ PATH-resolved wrapper scripts, so it isn't a drop-in swap for
  Ferrum's lookup — but worth revisiting whether `BROWSER_PATH`/explicit
  `browser_path:` can replace the hardcoded candidate list.

## Altitude

- **Thread-local driver smuggling in `Runner`**
  (`lib/lookbook_visual_tester/runner.rb`, `run_scenario`/`record_mismatch`/
  `driver`). The driver is stashed in `Thread.current[:lookbook_visual_tester_driver]`
  so `record_mismatch` can read `driver.page_source` several calls later,
  instead of being passed explicitly through
  `compare_against_baseline` → `build_result` → `record_mismatch`. Fix: thread
  `driver` through those method signatures and drop the thread-local.

- **`lookbook:approve` re-derives preview identity via filename suffix matching**
  (`lib/tasks/lookbook_visual_tester.rake`, `approve` task). It normalizes
  `preview_name` and matches file basenames by exact/`_suffix` string
  comparison instead of using the canonical naming already encapsulated in
  `ScenarioRun` (`preview_name`/`scenario_name`/`filename`). Has an existing
  regression test (`spec/integration/tasks_spec.rb`) guarding the current
  suffix behavior — any fix needs to preserve that test's intent, not just
  its assertions.

- **Release tooling defined as loose `def`s inside `Rakefile`'s `namespace :release`**
  (`Rakefile`, `load_dotenv`/`write_credentials`). `def` inside a
  namespace/task block doesn't actually scope to the namespace — it leaks as
  a global method. Should be extracted into a small class/module (mirrors how
  `ServerTestRunner` was pulled out of the rake task for the server-running
  concern).

- **`UpdatePreviews` re-resolves an already-known preview via `Runner`'s fuzzy pattern matcher**
  (`lib/lookbook_visual_tester/update_previews.rb:62` calling
  `Runner.new(pattern: preview.name)`). `Runner`'s pattern matching is a
  case-insensitive substring match designed for CLI convenience, not exact
  internal dispatch — a preview whose name is a substring of another's could
  cause extra screenshots. Fix needs `Runner` to accept an explicit
  preview/scenario reference for internal callers.

## Efficiency

- **`ImageTrimmer` and `ImageComparator` each decode the same screenshot from disk**
  (`lib/lookbook_visual_tester/runner.rb` `capture`/`compare_against_baseline`).
  `ImageTrimmer.call` reads+decodes+re-encodes the just-captured PNG, then
  `ImageComparator#call` reads and decodes that same file again moments
  later. Fix would have `ImageTrimmer` return the in-memory `ChunkyPNG::Image`
  and thread it into `ImageComparator` instead of both re-opening the file —
  requires changing both services' public interfaces.

- **`ServerTestRunner` parses `lookbook_host` as a URI three separate times**
  (`lib/lookbook_visual_tester/server_test_runner.rb`: `wait_for_server`,
  `validate_host!`, `spawn_server`). Could parse once in `call` and reuse.

- **Repeated `json_mode` / null-output-stream idiom across rake tasks**
  (`lib/tasks/lookbook_visual_tester.rake`: `screenshot`, `test`, `retry`,
  and `lookbook_visual_tester:images`). Same three-line
  "compute json_mode → open null-or-stdout → close-if-json" pattern
  copy-pasted four times; candidate for a small
  `with_task_output(json_mode) { |output| ... }` wrapper.

## Correctness (flagged in passing, not a `/simplify` finding — needs `/code-review`)

- **Possible double-append into `Runner#run`'s results array.** A reviewing
  agent noted `run_sequentially`'s `@results << run_scenario(...)` may
  interact with `compare_against_baseline`'s own `@results <<` inside
  `run_scenario`, potentially appending a result twice or appending the
  `@results` array itself. Not verified or fixed — worth a dedicated
  `/code-review` pass on `lib/lookbook_visual_tester/runner.rb`.
