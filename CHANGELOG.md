# Changelog

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
