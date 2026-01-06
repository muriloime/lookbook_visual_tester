# Lookbook Visual Tester Style Guide & Best Practices

## Project Overview
`lookbook_visual_tester` is a Ruby gem designed for visual regression testing of Lookbook previews. It uses `Ferrum` for headless browser interactions and `ChunkyPNG` for image comparison.

## Architecture & patterns

### Service Objects
- Isolate complex logic in service objects inheriting from `LookbookVisualTester::Service` (if applicable) or plain Ruby classes in `lib/lookbook_visual_tester/services/`.
- Examples: `ImageComparator`, `ScenarioFinder`.

### Configuration
- Use `LookbookVisualTester.configure` to set global options.
- Options are defined in `lib/lookbook_visual_tester/configuration.rb`.
- Default base path for screenshots is `coverage/screenshots` (as of v0.5.5).

### Path Handling
- Use `Pathname` for all file system paths.
- **Screenshot Structure**:
  - `[base_path]/[baseline|current|diffs]/[folder_name]/[filename].png`
  - `folder_name` is either the variant slug (e.g., `dark-mode`) or `default` if no variant is present.
  - Never allow files to be dumped at the root of the screenshot directories; always enforce a subdirectory.

## Visual Testing Logic

### Image Comparison
- **Dimension Mismatch**: Do not raise errors for images of different sizes.
  - Create a canvas size equal to the maximum width and height of the two images.
  - Compare overlapping pixels.
  - Mark non-overlapping pixels (from the larger image) as differences.
  - Used in: `LookbookVisualTester::Services::ImageComparator`.

### Screenshot Capture
- Use `Ferrum` to capture screenshots.
- Ensure consistent viewport sizes and wait for animations/fonts if necessary (managed in `Runner` logic).

## Testing (`RSpec`)

### Structure
- **Unit Tests**: `spec/lib/lookbook_visual_tester/...`
- **Integration Tests**: `spec/integration/...`
- Use `spec_helper.rb` for common setup.

### Best Practices
- **Reproduction Scripts**: somewhat complex bugs (like visual mismatches) should be isolated in top-level `repro_*.rb` scripts before fixing.
- **Mocking**: Be careful with circular dependencies when mocking `Lookbook` objects (e.g., `Scenario` <-> `Preview`). Use `allow(...).to receive(...)` logic in `before` blocks rather than definitions to break cycles.

## Versioning & Changelog
- **Versioning**: Semantic versioning in `lib/lookbook_visual_tester/version.rb`.
- **Changelog**: Maintain `CHANGELOG.md` with `[Unreleased]` and version headers. Group changes by `Added`, `Changed`, `Fixed`.

## Coding Style
- Standard Ruby style (indentation: 2 spaces).
- Prefer descriptive variable names over short cryptic ones.
- Use `frozen_string_literal: true` where appropriate (though not strictly enforced everywhere yet).

## Versioning & Changelog

When updating the version, make sure to update the `CHANGELOG.md` file with the new version number and a list of changes since the last release. The changes should be grouped by `Added`, `Changed`, and `Fixed`. Also update `README.md` accordingly.