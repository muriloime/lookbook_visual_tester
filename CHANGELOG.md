# Changelog

Here is the changelog for version **0.1.5** of *LookbookVisualTester*:

---

# Changelog

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
