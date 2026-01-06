# Changelog
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
