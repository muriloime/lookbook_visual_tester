# Changelog
## [0.7.1] - 2026-08-09

### Changed
- Bound the `rails` runtime dependency to `~> 8.0`.

## [0.7.0] - 2026-08-09

### Removed
- `cuprite` runtime dependency; legacy `LookbookVisualTester::SessionManager`, `CapybaraSetup`, `ScreenshotTaker`, and `BaselineManager` classes.
- ImageMagick `convert` and `compare` shell calls from the visual regression path.
- Hard-coded Devise/Warden/Pundit auth mocking inside the gem.
- Lookbook 1.x (`examples`) fallback — only Lookbook 2.x (`scenarios`) is supported.
- Global `$stdout` mutation in rake tasks.
- Version-fragile `check_preview_controller_config` introspection in `PreviewChecker`.

### Added
- Pure-Ruby `LookbookVisualTester::ImageTrimmer` (ChunkyPNG) — no ImageMagick needed to trim screenshots.
- `config.preview_checker_setup` host hook for providing auth/helpers during deep checks.
- `LookbookVisualTester::ServerTestRunner` and `rake lookbook:server_and_test` for unattended agent/CI runs (process-group cleanup, log capture, configurable timeout).
- `Runner#initialize(..., output:)` — injectable output stream for thread-safe/quiet runs.
- `LookbookVisualTester::BrowserDiscovery` plus `config.browser_path` / `LOOKBOOK_BROWSER_PATH` to resolve a real Chrome binary, avoiding PATH-resolved wrapper scripts that break headless mode.
- `config.browser_options` (defaults to `{ "headless" => "new" }`), `config.browser_timeout`, and `config.process_timeout` for robust modern-Chrome launches.

### Changed
- `copy_to_clipboard` now defaults to `false` (opt in to `xclip`).
- `automatic_run` is parsed as a boolean from the `LOOKBOOK_AUTOMATIC_RUN` env var.
- The Railtie `Lookbook.after_change` auto-run hook now drives the Ferrum `Runner` instead of the deleted Capybara `ScreenshotTaker`.
- `Runner#run_scenario` decomposed into focused private methods; the concurrent path stores its driver per-thread.
- `lookbook:approve` matches namespaced previews by exact base name or `_suffix`, so approving `ui/button/default` no longer also approves `ui_button_defaultmobile`.
- Ferrum dependency bumped to `>= 0.16` and launches with `--headless=new`, fixing "Multiple targets are not supported in headless mode" on modern Chrome builds.

## [0.6.0] - 2026-01-12

### Fixed
- **Deep Check Error Handling**: Fixed an issue where `deep_check` would fail to capture `ActionView::Template::Error` (and other rendering errors) in components that return a `Hash` payload (common in newer ViewComponent versions). The checker now correctly extracts the component from the hash and properly renders it to detect failures. [PR #123]

## [0.5.10] - 2026-01-12

### Added
- **Force Update**: Added support for forcibly updating all baselines via `rake lookbook:test[force]` or `UPDATE=true rake lookbook:test`.

### Changed
- **File Naming**: Improved screenshot file naming to use full directory paths (e.g., `folder/component/preview.png`) instead of flattened underscores. This prevents filename clashes between components with similar names in different namespaces (e.g., `Foo::Bar` vs `FooBar`) and preserves directory structure in the output.

## [0.5.9] - 2026-01-12

### Fixed
- **Deep Check**: Ensure `ActionView::Template::Error` is correctly reported as a failure in `rake lookbook:deep_check`. This fixes an issue where rendered error pages were being ignored.

## [0.5.8] - 2026-01-08

### ✨ New Features & Improvements
- **AI-Native Inspection Tools**: Added `lookbook:inspect` and `lookbook:context` Rake tasks to assist AI agents in understanding preview structure and code context.
- **Debug Artifacts**: Automatically save HTML DOM snapshots alongside failed visual regression tests for easier debugging.
- **Visual Tolerance**: Added `tolerance` configuration option and fuzzy matching (Euclidean distance) to `ImageComparator` to reduce flakiness.

## [0.5.7] - 2026-01-06

### Fixed
- **Flaky Screenshots**: Added `wait_time` configuration to `LookbookVisualTester.config` to allow explicit waiting before screenshot capture. This resolves blank or layout-only screenshots in slower environments.
- **Robust Driver**: Updated `FerrumDriver` to include consistent network idle checks and support the new `wait_time` option.

## [0.5.6] - 2026-01-06

### Fixed
- **Image Comparison**: Fixed `Dimensions mismatch` error by creating a diff canvas sized to the maximum dimensions of widely differing images.
- **Missing Action Error**: Resolved `ActionNotFound` for `render_scenario_to_string` by ensuring the preview controller properly includes `Lookbook::PreviewControllerActions`.
- **Unexpected Headers**: Fixed an issue where the `example_icons` preview in the dummy app included an unwanted `<h1>Icons</h1>` header.
- **Spec Fix**: Resolved a `SystemStackError` (circular dependency) in `ScenarioFinder` specs.

### Changed
- **Folder Structure**: Refactored screenshot organization. Non-variant screenshots are now stored in a `default` subfolder within `coverage/screenshots`.
- **Deep Check**: Enhanced `rake lookbook:deep_check` to validate that the configured preview controller supports required Lookbook actions.

## [0.5.5] - 2026-01-06

### Fixed
- **Image Comparison**: Fixed `Dimensions mismatch` error. Now, when images have different dimensions, a diff image is generated on a canvas sized to the maximum dimensions, clearly showing the differences and the mismatched areas.

### Changed
- **Folder Structure**: Screenshots are now saved in `coverage/screenshots` by default (previously `spec/visual_screenshots`).
- **Default Subfolder**: Non-variant screenshots are now stored in a `default` subfolder to maintain consistency with variant-based runs.

## [0.5.4] - 2026-01-06

### Fixed
- **Variants URL Generation**: Fixed a bug where setting `VARIANTS` caused a `JSON::ParserError` in Lookbook. Variant parameters are now correctly serialized to JSON in the preview URL.

### Fixed
- **Deep Check**: `rake lookbook:deep_check` now correctly detects and fails when a preview returns `nil` (implicit rendering) but the corresponding template is missing (`ViewComponent::MissingPreviewTemplateError`).
- **Deep Check**: `rake lookbook:deep_check` now exits with status 1 if any errors or failures are detected.

## [0.5.2] - 2026-01-04

### Fixed
- **Preview Checker**: Fixed a `NoMethodError` crash in `PreviewChecker` when encountering template-only Lookbook scenarios (scenarios without a corresponding method in the preview class).

## [0.5.1] - 2026-01-03

### Fixed
- **Deprecation Warning**: Replaced usage of `examples` with `scenarios` to resolve Lookbook deprecation warnings.

## [0.5.0] - 2026-01-03

### ✨ New Features & Improvements
- **Preview Health Checks**: Added new Rake tasks to verify preview integrity:
    - `lookbook:check`: Rapidly checks if previews load and instantiate without errors.
    - `lookbook:deep_check`: Verified previews by effectively rendering them to catch runtime and template errors.
    - `lookbook:missing`: Identifies ViewComponents that lack a corresponding preview.
- **Parallel Preview Checks**: Health checks run in parallel using `concurrent-ruby`.
- **Comprehensive Reporting**: Checks generate colored terminal output and a detailed HTML report (`coverage/preview_check_report.html`) including timing stats and slowest previews.
- **Custom Deep Check Setup**: Added `config.preview_checker_setup` to allow defining mocks (e.g., User, Warden) required for deep checking.

## [0.4.0] - 2026-01-03

### ✨ New Features & Improvements
- **Multiple Screenshot Variants**: Support for defining screenshot variants (e.g., specific viewports, themes) using Lookbook's `preview_display_options`.
  - Configurable via `VARIANTS` environment variable (JSON array).
  - Screenshots are saved in subdirectories corresponding to the variant options.
  - Automatic browser resizing based on `width` options.

### 🧹 Housekeeping
- **Removed Minitest**: Switched completely to RSpec for internal testing. Deleted unused Minitest files and configuration.

## [0.3.0] - 2026-01-03

### ✨ New Features & Improvements
- **Concurrent Screenshot Capture**: Speed up your test suite significantly by running screenshot capture in parallel.
  - Enabled by default with 4 threads.
  - Configurable via `LOOKBOOK_THREADS` environment variable or Rails configuration.
- **Configurable Concurrency**: Added `threads` configuration option.

## [0.2.0] - 2026-01-02

### ✨ New Features & Improvements
- **Visual Diff Aesthetics**: Unchanged context in diff images now rendered with a light blue tint for better human readability.
- **Standalone Test Harness**: Integrated a dummy Rails application within `spec/dummy` for self-contained development and testing.
- **Full-Flow Integration Tests**: Added RSpec integration tests that boot a local server and verify the entire screenshot/comparison pipeline.
- **Lookbook 2.x Compatibility**: Added robust support for Lookbook 2.x `scenarios` while maintaining compatibility with 1.x `examples`.
- **Filename Normalization**: Improved screenshot naming to handle nested preview paths and avoid directory conflicts.

### Fixed
- Fixed Ferrum driver compatibility issue with `traffic_factor` argument in `wait_for_idle`.
- Fixed various unit tests to correctly mock configuration and scenario run state.

## [0.1.6] - 2025-03-04

### Better search

- better search logic, add components_folder config


## [0.1.5] - 2025-02-26

### ✨ New Features & Improvements

- **State Management & History Tracking**  
  - Introduced a **state store** with the new `Store` class for better history management.  
  - Implemented file history tracking, enabling more efficient change monitoring.  

- **Component Refactoring**  
  - Improved **state and history handling** in `LookbookVisualTester`.  
  - Updated `ScreenshotTaker` signature for better integration with other system components.  
  - Refactored `CapybaraSetup` to enhance test environment flexibility.  
  - `UpdatePreviews` now inherits from `Service`, standardizing code structure.  
  - Improved **clipboard functionality**, allowing better manipulation and copying of screenshots.  

- **Testing & Code Quality Enhancements**  
  - Added new unit tests for `ScreenshotTaker` and `UpdatePreviews`.  
  - Refactored logging and scenario handling to improve maintainability.  


## [0.1.4] - 2025-02-20
### Added
- Extracted `n_threads` configuration for improved concurrency.
- Introduced `save_to_clipboard` functionality.
- Extracted configuration and scenario run logic into separate classes.

### Changed
- Migrated to **Concurrent Ruby** for better parallel execution.
- Refactored `report_generator`, `screenshot_taker`, and `session_manager`.

### Fixed
- Minor fixes in `report_generator` and `tasks`.

---

## [0.1.1] - 2024-12-18
### Added
- Instructions added to the README.
- Initial version bump to `0.1.1`.

---

## [0.1.0] - 2024-12-18
### Added
- Initial working version.
- Set up **Capybara**, **Railtie**, and core functionalities.
- Added basic documentation and CI/CD setup.
