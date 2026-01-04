<img src="./assets/logo.jpg" alt="Logo" width="300" />

# Lookbook Visual Tester

A powerful visual regression testing tool for [ViewComponent](https://viewcomponent.org/) via [Lookbook](https://lookbook.build/). It automates the process of capturing screenshots of your components, comparing them against baselines, and highlighting differences with human-friendly aesthetics.

### Key Features

- **Automated Visual Regression**: Captures and compares screenshots of all Lookbook previews.
- **Intelligent Diffing**: High-quality image comparison using `chunky_png`.
- **Human-Friendly Aesthetics**: Context is rendered with a light blue tint to make red highlights of differences pop.
- **Robust Capture**: Automatically disables animations, waits for network idle, and allows masking/cropping.
- **Lookbook Support**: Compatible with both Lookbook 1.x (`examples`) and 2.x (`scenarios`).
- **Internal Test Harness**: Includes a dummy Rails app for self-contained testing and development.

## Installation

### System Dependencies

The gem requires `imagemagick` for image processing and `xclip` for clipboard integration (Linux).

For Ubuntu-based systems:
```bash
sudo apt-get install imagemagick xclip
```

### Gem Installation

Add to your application's Gemfile:
```ruby
group :test do
  gem 'lookbook_visual_tester', '~> 0.5.3'
end
```

Then install:
```bash
bundle install
```

## Configuration

You can configure the tester in a Rails initializer:

```ruby
LookbookVisualTester.configure do |config|
  config.lookbook_host = "http://localhost:3000" # Where your rails app is running
  config.base_path = "spec/visual_regression"    # Root for screenshots
  config.copy_to_clipboard = true                # Enable xclip support
  config.threads = 4                             # Number of parallel threads (default: 4)
end
```

## Usage

### Running Visual Tests

The gem provides Rake tasks to execute the visual regression suite.

#### Run All Tests
Runs all Lookbook previews, generates a terminal summary, and creates an HTML report.
```bash
bundle exec rake lookbook:test
```

#### Test a Specific Preview
Filter previews by name or label.
```bash
bundle exec rake lookbook:screenshot[Button]
```

#### Configuration Overrides
You can override the host or other settings inline:
```bash
LOOKBOOK_HOST=http://localhost:5000 LOOKBOOK_THREADS=8 bundle exec rake lookbook:test
```

#### Screenshot Variants

You can run your visual tests against multiple configurations (variants), such as different themes or viewports, by leveraging Lookbook's `preview_display_options`.

1.  **Define Options in Lookbook**:
    Ensure your Rails app has display options configured:
    ```ruby
    # config/lookbook.rb
    Lookbook.config.preview_display_options = {
      theme: ["light", "dark"],
      width: [["Mobile", "375px"], ["Desktop", "1280px"]]
    }
    ```

2.  **Run with Variants**:
    Use the `VARIANTS` environment variable to define a JSON array of option sets to test.

    *Example: Run standard tests + Dark Mode + Mobile View*
    ```bash
    VARIANTS='[{}, {"theme":"dark"}, {"width":"Mobile"}]' bundle exec rake lookbook:test
    ```

    * **`{}`**: Runs the default/standard preview.
    * **`{"theme":"dark"}`**: Runs with `_display[theme]=dark`.
    * **`{"width":"Mobile"}`**: Runs with `_display[width]=375px` AND automatically resizes the browser window to 375px width.

    Screenshots for variants are saved in dedicated subfolders (e.g., `spec/visual_regression/baseline/theme-dark/`).


### Baseline Management

1. **First Run**: When you run the tests for the first time, all screenshots are saved as **Baselines**.
2. **Subsequent Runs**: New screenshots are compared against the baselines.
3. **Mismatches**: If a change is detected, a **Diff** image is generated.
4. **Approval**: To approve a change (update the baseline), simply copy the file from `current_run` to `baseline`. The HTML report provides a convenient "Copy Approval Command" button for this.

### Reporting

After running `rake lookbook:test`, a detailed HTML report is generated at:
`coverage/visual_report.html`

The report allows you to:
- See side-by-side comparisons of Baseline vs. Actual.
- View the diff highlighting changes in neon red.
- Quickly copy terminal commands to approve changes.


### Human-Readable Diffs

When a difference is detected, a diff image is generated where:
- **Neon Red**: Parts of the component that changed.
- **Blue Tint**: The unchanged context, making it easy to identify where the change occurred.

## Internal Testing (Development)

The project includes an internal dummy Rails application for testing the gem itself.

### Running the Test Suite
```bash
bundle exec rspec
```

### Running the Full Flow Integration Test
```bash
bundle exec rspec spec/integration/full_flow_spec.rb
```

### Preview Health Checks

The gem provides tasks to ensure your previews are healthy and up-to-date.

#### Check Load/Syntax
Checks if all previews can be loaded and instantiated without errors.
```bash
bundle exec rake lookbook:check
```

#### Deep Check (Render)
effectively renders all previews to catch runtime errors, missing templates, and other failures. Exits with status 1 if any errors are found.
```bash
bundle exec rake lookbook:deep_check
```

#### Find Missing Previews
Identifies components that don't have a corresponding preview file.
```bash
bundle exec rake lookbook:missing
```

## Next Steps

- **CI/CD Integration**: Provide recipes for GitHub Actions to run visual regression on PRs.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/muriloime/lookbook_visual_tester.

## Deployment

To release a new version:
1. Update the version in `lib/lookbook_visual_tester/version.rb`.
2. Run `bundle exec rake release`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
