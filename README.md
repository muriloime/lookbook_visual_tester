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
  gem 'lookbook_visual_tester'
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
end
```

## Usage

### Running Visual Tests

Run the rake task to execute the visual regression suite:

```bash
bundle exec rake lookbook_visual_tester:run
```

You can override the host inline:
```bash
bundle exec rake lookbook_visual_tester:run LOOKBOOK_HOST=http://localhost:5000
```

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

## Next Steps

- **Multi-Viewport Support**: Add ability to capture screenshots at different screen widths (Mobile, Tablet, Desktop).
- **CI/CD Integration**: Provide recipes for GitHub Actions to run visual regression on PRs.
- **Reporting Dashboard**: Generate a static HTML report to easily browse all diffs in a single view.
- **Concurrent Captures**: Optimize execution speed by parallelizing screenshot taking across multiple browser instances.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/muriloime/lookbook_visual_tester.

## Deployment

To release a new version:
1. Update the version in `lib/lookbook_visual_tester/version.rb`.
2. Run `bundle exec rake release`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
