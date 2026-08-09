# Lookbook Visual Tester Production Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden `lookbook_visual_tester` into a reliable, CI/agent-friendly visual regression tool by removing ImageMagick/Cuprite runtime dependencies, fixing thread-safety and auth-mocking issues, rewiring the legacy auto-watch flow onto the Ferrum `Runner`, and adding a server wrapper so agents can run it unattended.

**Architecture:** Keep the existing Ferrum-based `Runner` as the single visual regression path. Extract a pure-Ruby `ImageTrimmer` so screenshots can be cropped without ImageMagick. Replace hard-coded `User`/`Devise`/`Pundit` mocks in `PreviewChecker` with a host-provided `preview_checker_setup` block. Rewire the Railtie's `Lookbook.after_change` auto-run hook and `UpdatePreviews` to call `Runner` instead of the deleted Capybara/Cuprite `ScreenshotTaker`; delete the now-dead `BaselineManager`. Remove legacy Capybara/Cuprite code from the runtime gem. Add a hardened `ServerTestRunner` that starts Rails, waits for Lookbook, runs tests, and ensures cleanup.

**Tech Stack:** Ruby 3+, Rails 7/8, ViewComponent 4.x, Lookbook 2.x, Ferrum, ChunkyPNG, RSpec.

## Global Constraints

- No runtime dependency on ImageMagick or `xclip` for the visual test path.
- No global `$stdout` mutation; output must be thread-safe and injectable.
- No hard-coded `User`/`Devise`/`Pundit` mocks inside the gem. Auth setup must be host-provided via `config.preview_checker_setup`.
- Lookbook 2.x (`scenarios`) is the only supported target. Lookbook 1.x (`examples`) compatibility code is removed everywhere it appears.
- Every task ends with a green RSpec run for new/changed specs. The single Ferrum/Chrome integration spec (`spec/integration/full_flow_spec.rb`) is allowed to fail in headless environments without Chrome; it must not be made to pass by weakening assertions.
- Backwards-compatible config paths are preserved unless explicitly renamed and deprecated.
- `rubocop` must not be loaded in the test environment (it currently segfaults via `racc` on Ruby 3.4 when the dummy app `Bundler.require`s it).

## File Map

| File | Responsibility | Task |
|---|---|---|
| `Gemfile` | Move `rubocop` to `:development` so test env doesn't load it. | 2 |
| `lookbook_visual_tester.gemspec` | Drop `cuprite` runtime dep; keep `ferrum`, `chunky_png`, `concurrent-ruby`, `lookbook`, `rails`, `rainbow`, `benchmark`. | 2 |
| `lib/lookbook_visual_tester/configuration.rb` | Gem configuration: defaults, paths, hooks. Fix duplicate assignment + `automatic_run` parsing. | 1 |
| `lib/lookbook_visual_tester.rb` | Top-level loader. Drop legacy requires; add `image_trimmer` and `server_test_runner`. | 3 |
| `lib/lookbook_visual_tester/session_manager.rb` | Legacy Capybara/Cuprite session. **Delete**. | 3 |
| `lib/lookbook_visual_tester/capybara_setup.rb` | Legacy Capybara driver setup. **Delete**. | 3 |
| `lib/lookbook_visual_tester/screenshot_taker.rb` | Legacy Capybara screenshot path. **Delete**. | 3 |
| `lib/lookbook_visual_tester/baseline_manager.rb` | Dead code only used by deleted `ScreenshotTaker`. **Delete**. | 3 |
| `lib/lookbook_visual_tester/update_previews.rb` | Auto-watch change handler. Rewire to call `Runner` instead of `ScreenshotTaker`. | 3 |
| `lib/lookbook_visual_tester/railtie.rb` | Loads rake tasks; keeps auto-run hook (off by default), now backed by `Runner`. | 3 |
| `lib/lookbook_visual_tester/services/image_trimmer.rb` | Pure-Ruby image trimming with ChunkyPNG. | 4 |
| `lib/lookbook_visual_tester/services/image_comparator.rb` | ChunkyPNG diff (existing, no change). | — |
| `lib/lookbook_visual_tester/runner.rb` | Main visual test runner. Remove ImageMagick shell call, inject output, drop 1.x `examples` fallback, refactor `run_scenario`. | 5 |
| `lib/lookbook_visual_tester/preview_checker.rb` | Preview health checks. Replace hard-coded auth with setup hook; keep `preview_example` path; drop 1.x fallback. | 6 |
| `lib/tasks/lookbook_visual_tester.rake` | Rake tasks. Stop mutating `$stdout`; drop 1.x fallback; add `server_and_test`; fix `approve`. | 7, 8, 9 |
| `lib/lookbook_visual_tester/server_test_runner.rb` | Starts Rails, runs tests, cleans up. | 8 |
| `README.md` | Update installation, config reference, tasks. | 10 |
| `CHANGELOG.md` | Document breaking + behavior changes. | 10 |

---

## Task 1: Fix Configuration Defaults and the Host Setup Hook

**Files:**
- Modify: `lib/lookbook_visual_tester/configuration.rb`
- Test: `spec/lib/lookbook_visual_tester/configuration_spec.rb` (create)

**Interfaces:**
- Produces: `LookbookVisualTester.config.preview_checker_setup` (callable or `nil`), `LookbookVisualTester.config.copy_to_clipboard` defaults to `false`, `LookbookVisualTester.config.driver_adapter` defaults to `:ferrum`, `LookbookVisualTester.config.automatic_run` is a boolean parsed from the `LOOKBOOK_AUTOMATIC_RUN` env var, `config.mask_selectors = []` stays.

- [ ] **Step 1: Write the failing spec for the corrected defaults**

```ruby
require 'spec_helper'
require 'lookbook_visual_tester/configuration'

RSpec.describe LookbookVisualTester::Configuration do
  subject(:config) { described_class.new }

  it 'defaults copy_to_clipboard to false' do
    expect(config.copy_to_clipboard).to be(false)
  end

  it 'defaults driver_adapter to ferrum' do
    expect(config.driver_adapter).to eq(:ferrum)
  end

  it 'defaults automatic_run to false when env is unset' do
    allow(ENV).to receive(:fetch).with('LOOKBOOK_AUTOMATIC_RUN', 'false').and_return('false')
    expect(config.automatic_run).to be(false)
  end

  it 'parses automatic_run as true when LOOKBOOK_AUTOMATIC_RUN=true' do
    allow(ENV).to receive(:fetch).with('LOOKBOOK_AUTOMATIC_RUN', 'false').and_return('true')
    expect(config.automatic_run).to be(true)
  end

  it 'accepts a preview_checker_setup callable' do
    setup = -> { :ok }
    config.preview_checker_setup = setup
    expect(config.preview_checker_setup).to eq(setup)
  end

  it 'defaults preview_checker_setup to nil' do
    expect(config.preview_checker_setup).to be_nil
  end

  it 'keeps legacy wait_time default' do
    expect(config.wait_time).to eq(0.5)
  end
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/configuration_spec.rb`
Expected: FAIL — `copy_to_clipboard` is `true`, `automatic_run` is the string `"false"`.

- [ ] **Step 2: Fix the configuration**

```ruby
# lib/lookbook_visual_tester/configuration.rb
module LookbookVisualTester
  class Configuration
    attr_reader :base_path
    attr_accessor :lookbook_host, :ui_comparison, :diff_dir, :baseline_dir, :current_dir,
                  :history_dir, :history_keep_last_n, :threads, :copy_to_clipboard,
                  :components_folder, :automatic_run, :mask_selectors, :driver_adapter,
                  :preview_checker_setup, :logger, :wait_time, :tolerance

    DEFAULT_THREADS = 4

    def initialize
      root_path = if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
                    Rails.root
                  else
                    Pathname.new(Dir.pwd)
                  end

      @base_path = root_path.join('coverage/screenshots')
      @baseline_dir = @base_path.join('baseline')
      @current_dir = @base_path.join('current_run')
      @diff_dir = @base_path.join('diff')
      @history_dir = @base_path.join('history')
      @threads = ENV.fetch('LOOKBOOK_THREADS', DEFAULT_THREADS).to_i
      @history_keep_last_n = 5
      @copy_to_clipboard = false
      @components_folder = 'app/components'
      @automatic_run = ENV.fetch('LOOKBOOK_AUTOMATIC_RUN', 'false') == 'true'
      @mask_selectors = []
      @driver_adapter = :ferrum
      @preview_checker_setup = nil
      @wait_time = 0.5
      @tolerance = 0.0
      @logger = if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
                  Rails.logger
                else
                  require 'logger'
                  Logger.new($stdout).tap { |l| l.level = Logger::INFO }
                end

      @lookbook_host = ENV.fetch('LOOKBOOK_HOST', 'http://localhost:5000')
    end

    def base_path=(value)
      @base_path = Pathname.new(value)
      @baseline_dir = @base_path.join('baseline')
      @current_dir = @base_path.join('current_run')
      @diff_dir = @base_path.join('diff')
      @history_dir = @base_path.join('history')
    end

    class << self
      def config
        @config ||= new
      end

      def configure
        yield(config)
      end
    end
  end

  def self.config
    @config ||= Configuration.new
  end
end
```

Notes:
- Removed the duplicate `@preview_checker_setup = nil`.
- `automatic_run` is now a boolean, not the raw env string.
- `copy_to_clipboard` defaults to `false`. Hosts opt in explicitly.

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/configuration_spec.rb`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/lookbook_visual_tester/configuration.rb spec/lib/lookbook_visual_tester/configuration_spec.rb
git commit -m "fix(config): boolean automatic_run, default copy_to_clipboard false, dedupe setup hook"
```

---

## Task 2: Gemfile and Gemspec Hygiene

**Files:**
- Modify: `Gemfile`
- Modify: `lookbook_visual_tester.gemspec`

**Interfaces:**
- Produces: `rubocop` only in `group :development` (not loaded by `Bundler.require` in test env). `cuprite` removed from runtime dependencies. `capybara`/`cuprite` remain in the `:development, :test` group only for the legacy specs until Task 3 deletes them.

- [ ] **Step 1: Move `rubocop` to the development group in the Gemfile**

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in lookbook_visual_tester.gemspec
gemspec

gem 'rake', '~> 13.0'
gem 'minitest', '~> 5.16'

gem 'async'
gem 'async-http'
gem 'concurrent-ruby'
gem 'lookbook'
gem 'rails', '~> 8.0'

group :development do
  gem 'rubocop', '~> 1.66'
end

group :development, :test do
  gem 'capybara', '~> 3.35'
  gem 'cuprite', '~> 0.14'
  gem 'puma'
  gem 'rspec', '~> 3.10'
  gem 'view_component'
end
```

- [ ] **Step 2: Drop `cuprite` from the gemspec runtime dependencies**

In `lookbook_visual_tester.gemspec`, remove the `spec.add_dependency 'cuprite'` line. The runtime block becomes:

```ruby
spec.add_dependency 'benchmark'
spec.add_dependency 'chunky_png'
spec.add_dependency 'concurrent-ruby'
spec.add_dependency 'ferrum'
spec.add_dependency 'lookbook'
spec.add_dependency 'rails'
spec.add_dependency 'rainbow'
```

- [ ] **Step 3: Re-bundle and run the suite**

```bash
bundle install
bundle exec rspec
```

Expected: The suite loads without the `rubocop`/`racc` segfault. Existing specs pass except the Ferrum/Chrome integration spec (allowed failure).

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock lookbook_visual_tester.gemspec
git commit -m "chore: move rubocop to development, drop cuprite runtime dependency"
```

---

## Task 3: Remove Legacy Capybara/Cuprite Code and Rewire the Auto-Run Hook

**Files:**
- Modify: `lib/lookbook_visual_tester.rb`
- Modify: `lib/lookbook_visual_tester/railtie.rb`
- Modify: `lib/lookbook_visual_tester/update_previews.rb`
- Delete: `lib/lookbook_visual_tester/session_manager.rb`
- Delete: `lib/lookbook_visual_tester/capybara_setup.rb`
- Delete: `lib/lookbook_visual_tester/screenshot_taker.rb`
- Delete: `lib/lookbook_visual_tester/baseline_manager.rb`
- Delete: `spec/lib/lookbook_visual_tester/screenshot_taker_spec.rb`
- Modify: `spec/lib/lookbook_visual_tester/update_previews_spec.rb`

**Interfaces:**
- Produces: Top-level gem no longer requires `session_manager`, `capybara_setup`, `screenshot_taker`, or `baseline_manager`. `UpdatePreviews#process_changes` calls `LookbookVisualTester::Runner.new(pattern: <resolved pattern>).run` for each changed preview instead of `ScreenshotTaker`. The Railtie auto-run hook is unchanged in shape but is now backed by `Runner` and stays off unless `config.automatic_run` is true.

- [ ] **Step 1: Audit references before deleting**

Run:

```bash
grep -R "SessionManager\|CapybaraSetup\|ScreenshotTaker\|BaselineManager" lib/ spec/ README.md
```

Expected: references only in `update_previews.rb`, `railtie.rb` (none for BaselineManager outside its own file), and the legacy specs. `BaselineManager` has no callers — safe to delete.

- [ ] **Step 2: Rewire `UpdatePreviews` to use `Runner`**

```ruby
# lib/lookbook_visual_tester/update_previews.rb
require_relative 'service'

module LookbookVisualTester
  class UpdatePreviews < Service
    attr_reader :changes

    def initialize(changes)
      @changes = changes[:modified]
      @changes_hash = changes
    end

    def update_app_data
      LookbookVisualTester.data[:last_changed_files] = changes.presence || []
      LookbookVisualTester.data[:last_changed_previews] = selected_previews
    end

    def call
      Rails.logger.info "LookbookVisualTester: Processing changes for #{should_process?} #{selected_changes.inspect}, #{changes.inspect}"
      return unless should_process?

      process_changes
    rescue StandardError => e
      Rails.logger.error "LookbookVisualTester: Error processing changes: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    private

    def selected_changes
      @selected_changes ||= changes.select { |change| process_change?(change) }
    end

    def process_change?(change)
      change.to_s.downcase.include?('preview.rb') || change.to_s.downcase.match?(/component\.(html|haml|rb|erb)/)
    end

    def should_process?
      return false if changes.nil? || changes.empty?

      selected_changes.any?
    end

    def components_folder
      LookbookVisualTester.config.components_folder
    end

    def clean_file_name(file)
      file = file.split(components_folder)[-1]
      file.split('.')[0].gsub('_preview', '')
    end

    def selected_previews
      @selected_previews ||= Lookbook.previews.select do |preview|
        selected_changes.any? { |file| preview.file_path.to_s.include?(clean_file_name(file)) }
      end
    end

    def process_changes
      Rails.logger.info "LookbookVisualTester: previews #{selected_previews.count}"
      selected_previews.each do |preview|
        Rails.logger.info "LookbookVisualTester: running Runner for #{preview.inspect}"
        LookbookVisualTester::Runner.new(pattern: preview.name).run
      end
    end
  end
end
```

Notes:
- The stray `puts ">>>> #{file}"` debug line is removed.
- Each changed preview is re-run through the Ferrum `Runner` (the single visual regression path), filtered by `preview.name`.

- [ ] **Step 3: Update the Railtie (drop the legacy require, keep the hook)**

```ruby
# lib/lookbook_visual_tester/railtie.rb
module LookbookVisualTester
  class Railtie < ::Rails::Railtie
    rake_tasks do
      path = File.expand_path('../tasks/lookbook_visual_tester.rake', __dir__)
      load path
    end

    initializer 'LookbookVisualTester.lookbook_after_change' do |_app|
      Rails.logger.info "LookbookVisualTester initialized with host: #{LookbookVisualTester.config.lookbook_host}"
      Lookbook.after_change do |_app, changes|
        next unless LookbookVisualTester.config.automatic_run

        modified = changes[:modified]
        my_hash = modified.sort.map { |f| File.read(f) }.hash

        lock_file = Rails.root.join('tmp', 'lookbook_visual_tester.lock')
        Rails.logger.info ">>> LookbookVisualTester: No changes detected in #{LookbookVisualTester.data}"

        File.open(lock_file, 'w') do |file|
          if file.flock(File::LOCK_EX | File::LOCK_NB)
            if LookbookVisualTester.data[:last_hash] == my_hash
              Rails.logger.info 'LookbookVisualTester: No changes detected in Lookbook'
            else
              LookbookVisualTester.data[:last_hash] = my_hash
              Rails.logger.info "LookbookVisualTester: Running UpdatePreviews, updating to #{LookbookVisualTester.data.inspect}"
              LookbookVisualTester::UpdatePreviews.call(changes)
            end
            file.flock(File::LOCK_UN)
            Rails.logger.info 'LookbookVisualTester: UpdatePreviews File unlocked.'
          else
            Rails.logger.info 'LookbookVisualTester: UpdatePreviews already running, skipping this call.'
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Update the top-level loader (drop legacy requires, add `image_trimmer` and `server_test_runner`)**

```ruby
# lib/lookbook_visual_tester.rb
require_relative 'lookbook_visual_tester/version'
require_relative 'lookbook_visual_tester/configuration'
require_relative 'lookbook_visual_tester/railtie' if defined?(Rails)
require_relative 'lookbook_visual_tester/scenario_finder'
require_relative 'lookbook_visual_tester/store'
require_relative 'lookbook_visual_tester/runner'
require_relative 'lookbook_visual_tester/driver'
require_relative 'lookbook_visual_tester/drivers/ferrum_driver'
require_relative 'lookbook_visual_tester/services/image_comparator'
require_relative 'lookbook_visual_tester/services/image_trimmer'
require_relative 'lookbook_visual_tester/server_test_runner'

module LookbookVisualTester
  class Error < StandardError; end

  def self.configure
    yield(config)
  end
end
```

- [ ] **Step 5: Delete the legacy files and their specs**

```bash
rm lib/lookbook_visual_tester/session_manager.rb
rm lib/lookbook_visual_tester/capybara_setup.rb
rm lib/lookbook_visual_tester/screenshot_taker.rb
rm lib/lookbook_visual_tester/baseline_manager.rb
rm spec/lib/lookbook_visual_tester/screenshot_taker_spec.rb
```

- [ ] **Step 6: Update `update_previews_spec.rb` to expect `Runner` instead of `ScreenshotTaker`**

Replace the `describe '#process_changes'` block with:

```ruby
describe '#process_changes' do
  let(:modified_files) { ['app/components/button_preview.rb'] }
  let(:scenario) { double('scenario') }
  let(:preview) { double('preview', scenarios: [scenario], file_path: 'app/components/button_preview.rb', name: 'Button') }
  let(:runner) { double('Runner') }

  before do
    allow(preview).to receive(:respond_to?).with(:scenarios).and_return(true)
    allow(Lookbook).to receive(:previews).and_return([preview])
    allow(LookbookVisualTester::Runner).to receive(:new).with(pattern: 'Button').and_return(runner)
    allow(runner).to receive(:run)
    allow(Rails.logger).to receive(:info)
  end

  it 'runs the Ferrum Runner for each changed preview' do
    expect(LookbookVisualTester::Runner).to receive(:new).with(pattern: 'Button')
    expect(runner).to receive(:run)

    service.send(:process_changes)
  end
end
```

Also remove the `require 'lookbook_visual_tester/screenshot_taker'` line at the top of the spec.

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/update_previews_spec.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove legacy cuprite/capybara code, rewire auto-run to Ferrum Runner"
```

---

## Task 4: Implement Pure-Ruby Image Trimming

**Files:**
- Create: `lib/lookbook_visual_tester/services/image_trimmer.rb`
- Test: `spec/lib/lookbook_visual_tester/services/image_trimmer_spec.rb` (create)

**Interfaces:**
- `LookbookVisualTester::ImageTrimmer.call(path, padding: 10)` — reads PNG at `path`, trims fully-transparent or fully-white margins, adds `padding` pixels of transparent border, overwrites `path` with the result. Returns `path`. Idempotent, pure-Ruby, no shell calls.

- [ ] **Step 1: Write the failing spec**

```ruby
require 'spec_helper'
require 'lookbook_visual_tester/services/image_trimmer'
require 'chunky_png'
require 'fileutils'

RSpec.describe LookbookVisualTester::ImageTrimmer do
  let(:tmp_dir) { 'spec/tmp/trimmer' }
  let(:path) { "#{tmp_dir}/input.png" }

  before { FileUtils.mkdir_p(tmp_dir) }
  after  { FileUtils.rm_rf(tmp_dir) }

  def build_image(width:, height:, fill: ChunkyPNG::Color::WHITE, content_color: ChunkyPNG::Color::BLACK)
    image = ChunkyPNG::Image.new(width, height, fill)
    image[5, 5] = content_color
    image[6, 5] = content_color
    image[5, 6] = content_color
    image[6, 6] = content_color
    image
  end

  it 'trims white margins and adds padding' do
    build_image(width: 20, height: 20).save(path)

    described_class.call(path, padding: 4)

    trimmed = ChunkyPNG::Image.from_file(path)
    expect(trimmed.width).to eq(12)  # 2px blob + 4px padding each side
    expect(trimmed.height).to eq(12)
  end

  it 'preserves images that have no uniform border' do
    image = ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color.from_hex('#EFEFEF'))
    image.save(path)

    described_class.call(path, padding: 0)

    trimmed = ChunkyPNG::Image.from_file(path)
    expect(trimmed.width).to eq(10)
    expect(trimmed.height).to eq(10)
  end

  it 'raises when the file does not exist' do
    expect { described_class.call('spec/tmp/missing.png') }.to raise_error(Errno::ENOENT)
  end

  it 'returns the path' do
    build_image(width: 10, height: 10).save(path)
    expect(described_class.call(path)).to eq(path)
  end

  it 'does not shell out to ImageMagick' do
    build_image(width: 10, height: 10).save(path)
    expect(Kernel).not_to receive(:system).with(/convert/)
    expect(Kernel).not_to receive(:`).with(/convert/)
    described_class.call(path)
  end
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/services/image_trimmer_spec.rb`
Expected: FAIL — `ImageTrimmer` not defined.

- [ ] **Step 2: Implement `ImageTrimmer`**

```ruby
# lib/lookbook_visual_tester/services/image_trimmer.rb
require 'chunky_png'

module LookbookVisualTester
  module ImageTrimmer
    DEFAULT_PADDING = 10

    # Pixels matching any of these colors are considered "empty" border and trimmed.
    BORDER_COLORS = [
      ChunkyPNG::Color::WHITE,
      ChunkyPNG::Color::TRANSPARENT
    ].freeze

    def self.call(path, padding: DEFAULT_PADDING)
      image = ChunkyPNG::Image.from_file(path)

      min_x = image.width
      max_x = -1
      min_y = image.height
      max_y = -1

      image.height.times do |y|
        image.width.times do |x|
          next if border_pixel?(image[x, y])

          min_x = x if x < min_x
          max_x = x if x > max_x
          min_y = y if y < min_y
          max_y = y if y > max_y
        end
      end

      # No content found: keep the original image.
      return path if max_x < min_x

      content_width = max_x - min_x + 1
      content_height = max_y - min_y + 1
      new_width = content_width + (padding * 2)
      new_height = content_height + (padding * 2)

      trimmed = ChunkyPNG::Image.new(new_width, new_height, ChunkyPNG::Color::TRANSPARENT)

      image.height.times do |y|
        image.width.times do |x|
          next if x < min_x || x > max_x || y < min_y || y > max_y

          trimmed[x - min_x + padding, y - min_y + padding] = image[x, y]
        end
      end

      trimmed.save(path)
      path
    end

    def self.border_pixel?(color)
      BORDER_COLORS.include?(color)
    end
  end
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/services/image_trimmer_spec.rb`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/lookbook_visual_tester/services/image_trimmer.rb spec/lib/lookbook_visual_tester/services/image_trimmer_spec.rb
git commit -m "feat: pure-ruby image trimmer using chunky_png"
```

---

## Task 5: Harden the Runner (ImageMagick removal, output injection, refactor, drop 1.x fallback)

**Files:**
- Modify: `lib/lookbook_visual_tester/runner.rb`
- Test: `spec/lib/lookbook_visual_tester/runner_spec.rb`

**Interfaces:**
- `Runner.new(config = LookbookVisualTester.config, pattern: nil, force_update: false, output: $stdout)` accepts an IO-like output stream.
- `Runner#run_scenario` calls `LookbookVisualTester::ImageTrimmer.call(current_path.to_s)` instead of `system("convert ...")`.
- All progress output inside `Runner` goes through `@output.puts` / `@output.print` (no bare `puts`/`print`).
- `run_sequentially` and `run_concurrently` iterate `preview.scenarios` only (Lookbook 2.x); the `preview.examples` fallback is removed.
- `run_scenario` is decomposed into focused private methods: `prepare_paths`, `capture`, `compare_against_baseline`, `record_failure`, `copy_to_clipboard_if_enabled`.

- [ ] **Step 1: Add failing tests for output injection and no ImageMagick**

Append to `spec/lib/lookbook_visual_tester/runner_spec.rb`:

```ruby
context 'with a custom output stream' do
  let(:output) { StringIO.new }

  before do
    allow(LookbookVisualTester::ImageComparator).to receive(:new).and_return(
      double(call: { mismatch: 0.0 })
    )
    allow(FileUtils).to receive(:cp)
    allow(LookbookVisualTester::ImageTrimmer).to receive(:call).and_return('path')
  end

  it 'writes progress to the provided stream' do
    runner = described_class.new(output: output)
    runner.run

    expect(output.string).to include('Found 1 previews')
  end
end

context 'image trimming' do
  before do
    allow(LookbookVisualTester::ImageComparator).to receive(:new).and_return(
      double(call: { mismatch: 0.0 })
    )
    allow(FileUtils).to receive(:cp)
  end

  it 'trims the screenshot via ImageTrimmer without calling ImageMagick' do
    expect(Kernel).not_to receive(:system).with(/convert/)
    allow(LookbookVisualTester::ImageTrimmer).to receive(:call).and_call_original

    runner = described_class.new
    runner.run

    expect(LookbookVisualTester::ImageTrimmer).to have_received(:call).with(String).at_least(:once)
  end
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/runner_spec.rb`
Expected: FAIL — `Runner` has no `output:` keyword; `Kernel.system(/convert/)` is still called.

- [ ] **Step 2: Refactor `Runner`**

```ruby
# lib/lookbook_visual_tester/runner.rb
require 'lookbook'
require 'json'
require_relative 'configuration'
require_relative 'scenario_run'
require_relative 'services/image_comparator'
require_relative 'services/image_trimmer'
require_relative 'drivers/ferrum_driver'
require_relative 'variant_resolver'

module LookbookVisualTester
  class Runner
    Result = Struct.new(:scenario_name, :status, :mismatch, :diff_path, :error, :baseline_path,
                        :current_path, keyword_init: true)

    DEFAULT_DRIVER_WIDTH = 1280
    DEFAULT_DRIVER_HEIGHT = 800

    def initialize(config = LookbookVisualTester.config, pattern: nil, force_update: false, output: $stdout)
      @config = config
      @pattern = pattern
      @force_update = force_update
      @output = output
      @driver_pool = Queue.new
      init_driver_pool
      @results = []
      @variants = load_variants
    end

    def run
      previews = Lookbook.previews

      if @pattern.present?
        previews = previews.select do |preview|
          preview.label.downcase.include?(@pattern.downcase) ||
            preview.name.downcase.include?(@pattern.downcase)
        end
      end

      @output.puts "Found #{previews.count} previews matching '#{@pattern}'."
      @output.puts "Running against #{@variants.size} variant(s)."

      @variants.each do |variant_input|
        resolver = VariantResolver.new(variant_input)
        variant_options = resolver.resolve
        variant_slug = resolver.slug
        width = resolver.width_in_pixels

        @output.puts "  Variant: #{variant_slug.presence || 'Default'}"

        if @config.threads > 1
          run_concurrently(previews, variant_slug, variant_options, width)
        else
          run_sequentially(previews, variant_slug, variant_options, width)
        end
      end

      @results
    ensure
      cleanup_drivers
    end

    private

    def load_variants
      variants_json = ENV['VARIANTS'] || ENV.fetch('LOOKBOOK_VARIANTS', nil)
      return [{}] if variants_json.blank?

      begin
        JSON.parse(variants_json)
      rescue JSON::ParserError
        @output.puts 'Invalid JSON in VARIANTS env var. Defaulting to standard run.'
        [{}]
      end
    end

    def scenarios_for(preview)
      preview.scenarios
    end

    def run_sequentially(previews, variant_slug, variant_options, width)
      previews.each do |preview|
        scenarios_for(preview).each do |scenario|
          driver = checkout_driver
          begin
            @results << run_scenario(scenario, driver, variant_slug, variant_options, width)
          ensure
            return_driver(driver)
          end
        end
      end
    end

    def run_concurrently(previews, variant_slug, variant_options, width)
      require 'concurrent-ruby'
      pool = Concurrent::FixedThreadPool.new(@config.threads)
      promises = []

      previews.each do |preview|
        scenarios_for(preview).each do |scenario|
          promises << Concurrent::Promises.future_on(pool) do
            driver = checkout_driver
            begin
              run_scenario(scenario, driver, variant_slug, variant_options, width)
            ensure
              return_driver(driver)
            end
          end
        end
      end

      @results.concat(Concurrent::Promises.zip(*promises).value)
      pool.shutdown
      pool.wait_for_termination
    end

    def init_driver_pool
      count = @config.threads > 1 ? @config.threads : 1
      count.times { @driver_pool << Drivers::FerrumDriver.new(@config) }
    end

    def checkout_driver
      @driver_pool.pop
    end

    def return_driver(driver)
      @driver_pool << driver
    end

    def cleanup_drivers
      until @driver_pool.empty?
      driver = @driver_pool.pop
      driver.cleanup
    end
    end

    def run_scenario(scenario, driver, variant_slug, variant_options, width)
      run_data = ScenarioRun.new(scenario, variant_slug: variant_slug,
                                           display_params: variant_options)
      @output.puts "Running visual test for: #{run_data.name} #{variant_slug.present? ? "[#{variant_slug}]" : ''}"

      paths = prepare_paths(run_data, variant_slug)
      begin
        capture(driver, run_data, paths, width)
        compare_against_baseline(run_data, paths)
      rescue StandardError => e
        record_failure(run_data, paths, e)
      end
    end

    def prepare_paths(run_data, variant_slug)
      folder_name = variant_slug.presence || 'default'
      {
        current: run_data.current_path,
        baseline: run_data.baseline_path,
        diff: @config.diff_dir.join(folder_name, run_data.diff_filename)
      }
    end

    def capture(driver, run_data, paths, width)
      driver.resize_window(width || DEFAULT_DRIVER_WIDTH, DEFAULT_DRIVER_HEIGHT)
      driver.visit(run_data.preview_url)

      FileUtils.mkdir_p(File.dirname(paths[:current]))
      FileUtils.mkdir_p(File.dirname(paths[:diff]))

      driver.save_screenshot(paths[:current].to_s)
      ImageTrimmer.call(paths[:current].to_s) if File.exist?(paths[:current].to_s)
    end

    def compare_against_baseline(run_data, paths)
      comparator = ImageComparator.new(paths[:baseline].to_s, paths[:current].to_s, paths[:diff].to_s)
      result = comparator.call

      @results << build_result(run_data, paths, result)
    end

    def build_result(run_data, paths, result)
      if result[:error]
        if result[:error] == 'Baseline not found' || @force_update
          handle_missing_baseline(run_data, paths, result)
        else
          @output.puts "  [ERROR] #{result[:error]}"
          Result.new(scenario_name: run_data.name, status: :error, error: result[:error],
                     baseline_path: paths[:baseline].to_s, current_path: paths[:current].to_s)
        end
      elsif result[:mismatch] > 0
        record_mismatch(run_data, paths, result)
      else
        @output.puts '  [PASS] Identical.'
        Result.new(scenario_name: run_data.name, status: :passed, mismatch: 0.0,
                   diff_path: paths[:diff].to_s, baseline_path: paths[:baseline].to_s,
                   current_path: paths[:current].to_s)
      end
    end

    def handle_missing_baseline(run_data, paths, result)
      if @force_update
        @output.puts '  [UPDATE] Baseline forced update.'
        status = :passed
      else
        @output.puts '  [NEW] Baseline not found. Saved current as potential baseline.'
        status = :new
      end
      FileUtils.mkdir_p(File.dirname(paths[:baseline]))
      FileUtils.cp(paths[:current], paths[:baseline])
      Result.new(scenario_name: run_data.name, status: status, mismatch: 0.0,
                 diff_path: nil, baseline_path: paths[:baseline].to_s,
                 current_path: paths[:current].to_s)
    end

    def record_mismatch(run_data, paths, result)
      mismatch = result[:mismatch]
      @output.puts "  [FAIL] Mismatch: #{mismatch.round(2)}%. Diff saved to #{paths[:diff]}"

      dom_path = paths[:diff].sub('.png', '.html')
      File.write(dom_path, driver.page_source)
      @output.puts "         DOM Snapshot saved to #{dom_path}"

      copy_to_clipboard_if_enabled(paths[:current])

      Result.new(scenario_name: run_data.name, status: :failed, mismatch: mismatch,
                 diff_path: paths[:diff].to_s, baseline_path: paths[:baseline].to_s,
                 current_path: paths[:current].to_s)
    end

    def copy_to_clipboard_if_enabled(current_path)
      return unless @config.copy_to_clipboard

      system("xclip -selection clipboard -t image/png -i #{current_path}")
    end

    def record_failure(run_data, paths, error)
      @output.puts "  [ERROR] Exception: #{error.message}"
      @output.puts error.backtrace.take(5)
      Result.new(scenario_name: run_data.name, status: :error, error: error.message,
                 baseline_path: paths[:baseline].to_s, current_path: paths[:current].to_s)
    end

    # Used by record_mismatch; resolves the driver for the current scenario thread.
    def driver
      Thread.current[:lookbook_visual_tester_driver]
    end
  end
end
```

**Important fix-up note for the implementer:** `record_mismatch` references `driver.page_source`, but `driver` is local to `capture`. Pass the driver through to `run_scenario` and store it on the thread (or pass it as an argument to `record_mismatch`). The concrete pattern:

```ruby
def run_scenario(scenario, driver, variant_slug, variant_options, width)
  run_data = ScenarioRun.new(...)
  paths = prepare_paths(run_data, variant_slug)
  Thread.current[:lookbook_visual_tester_driver] = driver
  begin
    capture(driver, run_data, paths, width)
    compare_against_baseline(run_data, paths)
  rescue StandardError => e
    record_failure(run_data, paths, e)
  ensure
    Thread.current[:lookbook_visual_tester_driver] = nil
  end
end
```

`record_mismatch` reads `driver.page_source` via the `driver` helper above. Add this wiring so the DOM snapshot still works. Add a spec that asserts `driver.page_source` is written to the `.html` path on mismatch (stub the driver double to return `"<html>"` for `page_source`).

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/runner_spec.rb`
Expected: PASS (existing specs may need `output:` plumbing if they assert on stdout; update them to pass a `StringIO`).

- [ ] **Step 3: Commit**

```bash
git add lib/lookbook_visual_tester/runner.rb spec/lib/lookbook_visual_tester/runner_spec.rb
git commit -m "refactor(runner): pure-ruby trim, inject output, drop 1.x fallback, decompose run_scenario"
```

---

## Task 6: Refactor PreviewChecker to Use the Host Setup Hook

**Files:**
- Modify: `lib/lookbook_visual_tester/preview_checker.rb`
- Test: `spec/lib/lookbook_visual_tester/preview_checker_spec.rb`

**Interfaces:**
- `PreviewChecker#run_setup` calls `config.preview_checker_setup` if present, else does nothing.
- The hard-coded `build_mock_user`, `@mocks`, `define_singleton_method`, `signed_in?`/`policy` helpers, and `default_setup` are removed.
- `deep_render_check` keeps the existing `preview_class.respond_to?(:preview_example)` path (so implicit-template previews still work) and uses a minimal view context with no auth mocking.
- `check_preview_controller_config` is removed (it introspected Lookbook internals and was version-fragile).

- [ ] **Step 1: Add failing tests for the setup hook**

Append to `spec/lib/lookbook_visual_tester/preview_checker_spec.rb`:

```ruby
describe '#run_setup' do
  it 'calls the configured preview_checker_setup block' do
    called = false
    local_config = LookbookVisualTester::Configuration.new
    local_config.preview_checker_setup = -> { called = true }

    checker = described_class.new(local_config)
    checker.send(:run_setup)

    expect(called).to be(true)
  end

  it 'does nothing when no setup block is configured' do
    local_config = LookbookVisualTester::Configuration.new
    local_config.preview_checker_setup = nil

    checker = described_class.new(local_config)
    expect { checker.send(:run_setup) }.not_to raise_error
  end
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/preview_checker_spec.rb`
Expected: FAIL — current `run_setup` calls `default_setup` (which builds mocks) when the block is absent.

- [ ] **Step 2: Replace `PreviewChecker` body**

```ruby
# lib/lookbook_visual_tester/preview_checker.rb
require 'concurrent'
require 'benchmark'

module LookbookVisualTester
  class PreviewChecker
    CheckResult = Struct.new(:preview_name, :example_name, :status, :error, :backtrace, :duration,
                             keyword_init: true)
    MissingResult = Struct.new(:component_path, keyword_init: true)

    def initialize(config = LookbookVisualTester.config)
      @config = config
    end

    def check
      run_checks(:basic_check)
    end

    def deep_check
      run_setup
      run_checks(:deep_render_check)
    end

    def missing
      components_dir = Rails.root.join(@config.components_folder)
      previews_dir = preview_paths.first

      components = Dir.glob(File.join(components_dir, '**', '*_component.rb'))

      missing = []
      components.each do |component_path|
        next if component_path.end_with?('application_component.rb')
        next if component_path.include?('/concerns/')

        relative_path = Pathname.new(component_path).relative_path_from(components_dir).to_s
        preview_relative_path = relative_path.sub('_component.rb', '_component_preview.rb')
        preview_path = File.join(previews_dir, preview_relative_path)

        missing << MissingResult.new(component_path: relative_path) unless File.exist?(preview_path)
      end
      missing
    end

    private

    def preview_paths
      if defined?(Rails) && Rails.application.config.view_component.preview_paths.any?
        Rails.application.config.view_component.preview_paths.map { |p| Pathname.new(p) }
      else
        [Rails.root.join('test/components/previews')]
      end
    end

    def run_setup
      @config.preview_checker_setup&.call
    end

    def run_checks(check_method)
      previews = Lookbook.previews
      work_items = previews.flat_map do |preview|
        preview.scenarios.map { |example| { preview: preview, example: example } }
      end

      if @config.threads > 1
        pool = Concurrent::FixedThreadPool.new(@config.threads)
        promises = work_items.map do |item|
          Concurrent::Promises.future_on(pool) do
            measure_and_send(item[:preview], item[:example], check_method)
          end
        end
        results = Concurrent::Promises.zip(*promises).value
        pool.shutdown
        pool.wait_for_termination
        results
      else
        work_items.map { |item| measure_and_send(item[:preview], item[:example], check_method) }
      end
    end

    def measure_and_send(preview, example, method_name)
      result = nil
      time = Benchmark.realtime { result = send(method_name, preview, example) }
      result.duration = time
      result
    end

    def basic_check(preview, example)
      preview_class = preview.preview_class
      example_name = example.name

      begin
        preview_instance = preview_class.new
        return CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed) unless preview_instance.respond_to?(example_name)

        preview_instance.public_send(example_name)
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed)
      rescue StandardError => e
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :failed,
                        error: e.message, backtrace: e.backtrace)
      end
    end

    def deep_render_check(preview, example)
      preview_class = preview.preview_class
      example_name = example.name

      begin
        if preview_class.respond_to?(:preview_example)
          result = preview_class.preview_example(example_name)
        else
          preview_instance = preview_class.new
          return CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed) unless preview_instance.respond_to?(example_name)
          result = preview_instance.public_send(example_name)
        end

        result = result[:component] if result.is_a?(Hash) && result.key?(:component)

        if result.respond_to?(:render_in)
          output = result.render_in(build_view_context)
          if output.is_a?(String) && output.include?('ActionView::Template::Error')
            return CheckResult.new(preview_name: preview.name, example_name: example_name,
                                   status: :failed, error: 'ActionView::Template::Error found in rendered output',
                                   backtrace: [])
          end
        elsif result.is_a?(String)
          if result.include?('ActionView::Template::Error')
            return CheckResult.new(preview_name: preview.name, example_name: example_name,
                                   status: :failed, error: 'ActionView::Template::Error found in rendered output',
                                   backtrace: [])
          end
        elsif result.nil?
          verify_implicit_template!(preview_class, example_name)
        end

        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed)
      rescue StandardError => e
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :failed,
                        error: e.message, backtrace: e.backtrace)
      end
    end

    def build_view_context
      controller = if defined?(ApplicationController)
                     ApplicationController.new
                   else
                     ActionController::Base.new
                   end
      controller.request = ActionDispatch::TestRequest.create
      controller.view_context
    end

    def verify_implicit_template!(preview_class, example_name)
      method = preview_class.instance_method(example_name)
      source_file = method&.source_location&.first
      return if source_file.nil?

      dir = File.dirname(source_file)
      filename = File.basename(source_file, '.rb')
      template_dir = File.join(dir, filename)

      extensions = ['.html.erb', '.html.haml', '.html.slim']
      path = File.join(template_dir, example_name)

      return if extensions.any? { |ext| File.exist?("#{path}#{ext}") }

      raise ViewComponent::MissingPreviewTemplateError.new(
        "Preview #{example_name} returned nil and no template found at #{path}.* (checked erb, haml, slim)"
      ) if defined?(ViewComponent::MissingPreviewTemplateError)

      raise "Preview returned nil and no template found at #{path}.*"
    end
  end
end
```

Notes:
- `run_setup` no longer falls back to `default_setup`; hosts that need `Current.user`/helpers set `config.preview_checker_setup`.
- `build_view_context` provides a minimal context with no Devise/Warden/Pundit mocking.
- `preview_example` path is preserved so implicit-template previews keep working.
- `check_preview_controller_config` is removed.

Update the existing `describe '#deep_check'` specs: remove the `allow(checker).to receive(:setup_view_context)` stub (the method no longer exists) and instead stub `build_view_context` if needed.

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/preview_checker_spec.rb spec/lib/lookbook_visual_tester/check_action_view_error_spec.rb spec/lib/lookbook_visual_tester/deep_check_error_handling_spec.rb`
Expected: PASS (adjust any specs that relied on deleted internals).

- [ ] **Step 3: Commit**

```bash
git add lib/lookbook_visual_tester/preview_checker.rb spec/lib/lookbook_visual_tester/preview_checker_spec.rb
git commit -m "refactor(preview_checker): host setup hook, remove auth mocks, keep preview_example path"
```

---

## Task 7: Rake Tasks — Stop Mutating `$stdout`, Drop 1.x Fallback

**Files:**
- Modify: `lib/tasks/lookbook_visual_tester.rake`
- Test: `spec/integration/tasks_spec.rb`

**Interfaces:**
- `lookbook:screenshot`, `lookbook:test`, `lookbook:retry`, `lookbook_visual_tester:images`, and `lookbook_visual_tester:profile` never reassign `$stdout`. When quiet/JSON mode is requested they pass `output: File.open(File::NULL, 'w')` to `Runner`.
- `lookbook:list` uses `preview.scenarios` only.

- [ ] **Step 1: Add a failing test that `$stdout` is never reassigned**

Append to `spec/integration/tasks_spec.rb`:

```ruby
it 'does not reassign $stdout during lookbook:test in json mode' do
  original = $stdout
  allow(LookbookVisualTester::Runner).to receive(:new).and_return(
    double(run: [], 'class' => LookbookVisualTester::Runner)
  )
  Rake::Task['lookbook:test'].reenable
  Rake::Task['lookbook:test'].invoke('json')

  expect($stdout).to equal(original)
end
```

Run: `bundle exec rspec spec/integration/tasks_spec.rb`
Expected: FAIL — current tasks reassign `$stdout`.

- [ ] **Step 2: Refactor the rake tasks**

For `lookbook:screenshot`:

```ruby
desc 'Generate screenshots for a specific preview (and run comparison)'
task :screenshot, %i[preview_name format] => :environment do |_, args|
  preview_name = args[:preview_name]
  format = args[:format]
  json_mode = format == 'json'

  unless preview_name
    if json_mode
      LookbookVisualTester::JsonOutputHandler.print({ error: 'Please provide a preview name' })
    else
      puts 'Please provide a preview name: rake lookbook:screenshot[Button]'
    end
    exit 1
  end

  output = json_mode ? File.open(File::NULL, 'w') : $stdout
  runner = LookbookVisualTester::Runner.new(pattern: preview_name, output: output)
  results = runner.run
  output.close if json_mode

  if json_mode
    json_results = results.map do |r|
      { scenario_name: r.scenario_name, status: r.status, mismatch: r.mismatch,
        diff_path: r.diff_path, baseline_path: r.baseline_path,
        current_path: r.current_path, error: r.error }
    end
    output_payload = json_results.size == 1 ? json_results.first : json_results
    LookbookVisualTester::JsonOutputHandler.print(output_payload)
  else
    print_cli_summary(results)
  end
end
```

For `lookbook:test`:

```ruby
desc 'Run visual regression tests for all previews'
task :test, [:format] => :environment do |_, args|
  json_mode = args[:format] == 'json' || ENV['JSON_OUTPUT'] == 'true'
  output = json_mode ? File.open(File::NULL, 'w') : $stdout

  runner = LookbookVisualTester::Runner.new(
    force_update: args[:format] == 'force' || ENV['UPDATE'] == 'true',
    output: output
  )
  results = runner.run
  output.close if json_mode

  if defined?(LookbookVisualTester.config.diff_dir)
    result_file = LookbookVisualTester.config.diff_dir.join('last_run.json')
    FileUtils.mkdir_p(File.dirname(result_file))
    simplified = results.map do |r|
      { scenario_name: r.scenario_name, status: r.status, mismatch: r.mismatch,
        diff_path: r.diff_path.to_s, current_path: r.current_path.to_s,
        baseline_path: r.baseline_path.to_s }
    end
    File.write(result_file, JSON.dump(simplified))
  end

  if json_mode
    summary = {
      total: results.size,
      passed: results.count { |r| r.status == :passed },
      failed: results.count { |r| r.status == :failed },
      new: results.count { |r| r.status == :new },
      errors: results.count { |r| r.status == :error },
      results: results.map do |r|
        { name: r.scenario_name, status: r.status, mismatch: r.mismatch, diff_path: r.diff_path }
      end
    }
    LookbookVisualTester::JsonOutputHandler.print(summary)
  else
    print_cli_summary(results)
    LookbookVisualTester::ReportGenerator.new(results).call
    exit 1 if results.any? { |r| r.status == :failed }
  end
end
```

For `lookbook:retry`:

```ruby
desc 'Re-run only failing tests from the last run'
task :retry, [:format] => :environment do |_, args|
  result_file = LookbookVisualTester.config.diff_dir.join('last_run.json')
  unless File.exist?(result_file)
    puts "No previous run data found at #{result_file}. Run 'rake lookbook:test' first."
    exit 1
  end

  last_run = JSON.parse(File.read(result_file), symbolize_names: true)
  failures = last_run.select { |r| r[:status] == 'failed' || r[:status] == 'error' }

  if failures.empty?
    puts 'No failures found in last run.'
    exit 0
  end

  puts "Retrying #{failures.size} failure(s)..."

  json_mode = args[:format] == 'json' || ENV['JSON_OUTPUT'] == 'true'
  output = json_mode ? File.open(File::NULL, 'w') : $stdout
  begin
    failures.each do |failure|
      puts "Retrying #{failure[:scenario_name]}..."
      LookbookVisualTester::Runner.new(pattern: failure[:scenario_name], output: output).run
    end
  ensure
    output.close if json_mode
  end
end
```

For `lookbook:list`, replace:

```ruby
group = preview.respond_to?(:scenarios) ? preview.scenarios : preview.examples
```

with:

```ruby
group = preview.scenarios
```

For `lookbook_visual_tester:images`, replace the `$stdout` mutation:

```ruby
if args[:skip_capture].to_s == 'true'
  # Just print existing
else
  runner = LookbookVisualTester::Runner.new(pattern: args[:name], output: File.open(File::NULL, 'w'))
  runner.run
end
```

For `lookbook_visual_tester:profile`, replace `$stdout = File.new('/dev/null', 'w')` patterns with passing `output:` to `Runner` (or keep `RubyProf` printing to `$stdout` since that is the profile output, not Runner noise — only silence the Runner). Concretely, do not mutate `$stdout` at all; if Runner noise is unwanted, pass `output: File.open(File::NULL, 'w')` to the invoked test task by refactoring `lookbook:test` to accept an `output` env override. Keep this task minimal: leave `$stdout` alone.

Run: `bundle exec rspec spec/integration/tasks_spec.rb`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/tasks/lookbook_visual_tester.rake spec/integration/tasks_spec.rb
git commit -m "refactor(rake): inject null output instead of mutating $stdout, drop 1.x fallback"
```

---

## Task 8: Server Wrapper for Agent Automation

**Files:**
- Create: `lib/lookbook_visual_tester/server_test_runner.rb`
- Create: `spec/lib/lookbook_visual_tester/server_test_runner_spec.rb`
- Modify: `lib/tasks/lookbook_visual_tester.rake`
- Modify: `spec/integration/tasks_spec.rb`

**Interfaces:**
- `LookbookVisualTester::ServerTestRunner.call(config: LookbookVisualTester.config, timeout: 60, test_task: 'lookbook:test', log_path: nil)` starts Rails in a child process (new process group), polls the Lookbook endpoint, invokes the test task, and ensures the whole process group is terminated.
- `rake lookbook:server_and_test` delegates to it.

- [ ] **Step 1: Write the spec**

```ruby
require 'spec_helper'
require 'lookbook_visual_tester/server_test_runner'

RSpec.describe LookbookVisualTester::ServerTestRunner do
  let(:config) { LookbookVisualTester::Configuration.new }

  before do
    allow(LookbookVisualTester).to receive(:config).and_return(config)
    config.lookbook_host = 'http://localhost:5000'
  end

  it 'requires a lookbook_host' do
    config.lookbook_host = nil
    expect { described_class.call }.to raise_error(LookbookVisualTester::Error, /lookbook_host/)
  end

  it 'raises on an invalid lookbook_host URL' do
    config.lookbook_host = 'not-a-url'
    expect { described_class.call }.to raise_error(LookbookVisualTester::Error, /lookbook_host/)
  end

  describe '.wait_for_server' do
    it 'returns true when the server responds < 500' do
      allow(Net::HTTP).to receive(:get_response).and_return(double(code: '200'))
      expect(described_class.wait_for_server(config.lookbook_host, timeout: 1)).to be(true)
    end

    it 'raises when the server never responds' do
      allow(Net::HTTP).to receive(:get_response).and_raise(Errno::ECONNREFUSED)
      expect { described_class.wait_for_server(config.lookbook_host, timeout: 0.1) }.to raise_error(LookbookVisualTester::Error, /did not start/)
    end
  end

  describe 'rake task registration' do
    it 'registers lookbook:server_and_test' do
      expect(Rake::Task.task_defined?('lookbook:server_and_test')).to be(true)
    end
  end
end
```

Add to `spec/integration/tasks_spec.rb`:

```ruby
it 'registers lookbook:server_and_test' do
  expect(Rake::Task.task_defined?('lookbook:server_and_test')).to be true
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/server_test_runner_spec.rb`
Expected: FAIL — file/class does not exist; task not registered.

- [ ] **Step 2: Implement `ServerTestRunner`**

```ruby
# lib/lookbook_visual_tester/server_test_runner.rb
require 'net/http'
require 'uri'
require 'timeout'
require 'tempfile'

module LookbookVisualTester
  class ServerTestRunner
    DEFAULT_TEST_TASK = 'lookbook:test'
    DEFAULT_TIMEOUT = 60
    POLL_INTERVAL = 0.25

    def self.call(config: LookbookVisualTester.config, timeout: DEFAULT_TIMEOUT, test_task: DEFAULT_TEST_TASK, log_path: nil)
      new(config: config, timeout: timeout, test_task: test_task, log_path: log_path).call
    end

    def initialize(config: LookbookVisualTester.config, timeout: DEFAULT_TIMEOUT, test_task: DEFAULT_TEST_TASK, log_path: nil)
      @config = config
      @timeout = timeout
      @test_task = test_task
      @log_path = log_path
      @pid = nil
      @log_file = nil
    end

    def call
      validate_host!
      @pid = spawn_server

      begin
        self.class.wait_for_server(@config.lookbook_host, timeout: @timeout)
        puts "[LookbookVisualTester] Server ready at #{@config.lookbook_host}. Running #{@test_task}..."

        task = Rake::Task[@test_task]
        task.reenable
        task.invoke
      ensure
        stop_server
      end
    end

    def self.wait_for_server(host, timeout: DEFAULT_TIMEOUT)
      uri = URI.parse(host)
      raise Error, "Invalid lookbook_host: #{host}" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      Timeout.timeout(timeout) do
        loop do
          begin
            response = Net::HTTP.get_response(uri)
            return true if response.code.to_i < 500
          rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::OpenTimeout, Net::ReadTimeout
            # server not ready yet
          end
          sleep POLL_INTERVAL
        end
      end
    rescue Timeout::Error
      raise Error, "Lookbook server at #{host} did not start within #{timeout}s"
    end

    private

    def validate_host!
      host = @config.lookbook_host
      raise Error, 'lookbook_host must be configured' if host.nil? || host.empty?

      uri = URI.parse(host)
      raise Error, "Invalid lookbook_host: #{host}" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise Error, "lookbook_host must include a port: #{host}" unless uri.port
    end

    def spawn_server
      port = URI.parse(@config.lookbook_host).port
      env = {
        'PORT' => port.to_s,
        'RAILS_ENV' => ENV.fetch('RAILS_ENV', 'development')
      }
      command = ['bundle', 'exec', 'rails', 'server', '-p', port.to_s]

      @log_file = @log_path ? File.open(@log_path, 'w') : Tempfile.create('lookbook_server')
      Process.spawn(env, *command, out: @log_file, err: @log_file, pgroup: true)
    end

    def stop_server
      return unless @pid

      begin
        Process.kill('-TERM', @pid) # negative pid signals the whole process group
      rescue Errno::ESRCH
        # already gone
      end

      begin
        Process.waitpid(@pid)
      rescue Errno::ECHILD
        # already reaped
      end
    ensure
      @log_file&.close
    end
  end
end
```

Add to `lib/lookbook_visual_tester.rb` (already added in Task 3):

```ruby
require_relative 'lookbook_visual_tester/server_test_runner'
```

- [ ] **Step 3: Add the rake task**

In `lib/tasks/lookbook_visual_tester.rake`, inside the `namespace :lookbook` block:

```ruby
desc 'Start Rails server, run visual tests, then stop the server'
task server_and_test: :environment do
  LookbookVisualTester::ServerTestRunner.call(
    timeout: ENV.fetch('LOOKBOOK_SERVER_TIMEOUT', '60').to_i,
    test_task: 'lookbook:test',
    log_path: ENV['LOOKBOOK_SERVER_LOG']
  )
end
```

Run: `bundle exec rspec spec/lib/lookbook_visual_tester/server_test_runner_spec.rb spec/integration/tasks_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/lookbook_visual_tester/server_test_runner.rb spec/lib/lookbook_visual_tester/server_test_runner_spec.rb lib/tasks/lookbook_visual_tester.rake spec/integration/tasks_spec.rb
git commit -m "feat: hardened server wrapper for unattended agent runs"
```

---

## Task 9: Fix `lookbook:approve` for Namespaced Previews

**Files:**
- Modify: `lib/tasks/lookbook_visual_tester.rake`
- Modify: `spec/integration/tasks_spec.rb`

**Interfaces:**
- `rake "lookbook:approve[ui/button/default]"` locates files under `current_run/**/<normalized>.png` (excluding `_diff.png`) where the base name equals `ui_button_default` exactly, or ends with `_ui_button_default` to support variant subfolders. Each is copied to the matching `baseline/` path (preserving subfolders).

- [ ] **Step 1: Inspect current file naming**

`ScenarioRun#filename` = `"#{preview_name}_#{scenario_name}.png"` with `preview_name`/`scenario_name` underscored. For a namespaced preview `Ui::ButtonComponentPreview` with scenario `default`, `preview.name` is `Ui::Button` (Lookbook strips `ComponentPreview`), so `preview_name` becomes `ui_button` and the file is `ui_button_default.png`. Approval by `ui/button/default` must match `ui_button_default.png` exactly — not as a prefix, otherwise `ui_button_defaultmobile` would also match.

- [ ] **Step 2: Rewrite the approve task**

```ruby
desc 'Approve a specific preview change (update baseline)'
task :approve, [:preview_name] => :environment do |_, args|
  preview_name = args[:preview_name]
  unless preview_name
    puts 'Please provide a preview name: rake "lookbook:approve[ui/button/default]"'
    exit 1
  end

  normalized = preview_name.tr('/', '_').tr(' ', '_')
  baseline_dir = LookbookVisualTester.config.baseline_dir
  current_dir = LookbookVisualTester.config.current_dir

  candidates = Dir.glob(current_dir.join('**', '*.png')).reject do |f|
    File.basename(f).end_with?('_diff.png')
  end.select do |f|
    base = File.basename(f, '.png')
    base == normalized || base.end_with?("_#{normalized}")
  end

  if candidates.empty?
    puts "No current runs found matching '#{preview_name}' in #{current_dir}."
    exit 1
  end

  candidates.each do |current_file|
    relative = Pathname.new(current_file).relative_path_from(current_dir)
    baseline_file = baseline_dir.join(relative)
    FileUtils.mkdir_p(File.dirname(baseline_file))
    FileUtils.cp(current_file, baseline_file)
    puts "Approved: #{relative}"
  end
end
```

- [ ] **Step 3: Add a spec**

Append to `spec/integration/tasks_spec.rb`:

```ruby
describe 'lookbook:approve' do
  it 'approves the correct baseline file for a namespaced preview' do
    current_dir = LookbookVisualTester.config.current_dir
    baseline_dir = LookbookVisualTester.config.baseline_dir
    FileUtils.mkdir_p(current_dir.join('theme-dark'))

    file = current_dir.join('theme-dark/ui_button_default.png')
    File.write(file, 'fake-png-data')

    # A differently-named preview that shares the prefix must NOT be approved.
    decoy = current_dir.join('theme-dark/ui_button_defaultmobile.png')
    File.write(decoy, 'should-not-be-approved')

    Rake::Task['lookbook:approve'].reenable
    Rake::Task['lookbook:approve'].invoke('ui/button/default')

    expect(File.exist?(baseline_dir.join('theme-dark/ui_button_default.png'))).to be(true)
    expect(File.exist?(baseline_dir.join('theme-dark/ui_button_defaultmobile.png'))).to be(false)
  end
end
```

Run: `bundle exec rspec spec/integration/tasks_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/tasks/lookbook_visual_tester.rake spec/integration/tasks_spec.rb
git commit -m "fix(approve): exact + suffix match for namespaced previews"
```

---

## Task 10: Update README and CHANGELOG

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update README system dependencies**

Remove the `imagemagick`/`xclip` system dependency block. Replace with:

> This gem uses Ferrum (Chrome) and ChunkyPNG. You need a Chrome-compatible browser installed locally. No ImageMagick or xclip required. Clipboard support via `xclip` is optional and opt-in (`config.copy_to_clipboard = true`).

- [ ] **Step 2: Update the README configuration example**

```ruby
LookbookVisualTester.configure do |config|
  config.lookbook_host = "http://localhost:5000"
  config.base_path = "coverage/screenshots"
  config.threads = 4
  config.wait_time = 0.5
  config.tolerance = 0.0
  config.copy_to_clipboard = false # default; opt in to xclip
  config.preview_checker_setup = -> {
    # Provide auth/helpers for deep checks, e.g.:
    # Current.user = LookbookFixtures.demo_user
  }
end
```

- [ ] **Step 3: Document the new task**

```bash
bundle exec rake lookbook:server_and_test
```

> Starts Rails, waits for Lookbook to be reachable, runs `lookbook:test`, and stops the server. Set `LOOKBOOK_SERVER_TIMEOUT` (seconds) and optional `LOOKBOOK_SERVER_LOG` (path to capture server output) as needed.

Also remove the "Compatible with both Lookbook 1.x (`examples`) and 2.x (`scenarios`)" line from the features list — only Lookbook 2.x is now supported.

- [ ] **Step 4: Update CHANGELOG**

Add an entry documenting:
- **Removed:** `cuprite` runtime dependency; legacy `SessionManager`/`CapybaraSetup`/`ScreenshotTaker`/`BaselineManager`; ImageMagick `convert` and `compare` shell calls; hard-coded Devise/Pundit auth mocking; Lookbook 1.x `examples` fallback; `$stdout` mutation in rake tasks; `check_preview_controller_config` introspection.
- **Added:** pure-Ruby `ImageTrimmer` (ChunkyPNG); `config.preview_checker_setup` host hook; `ServerTestRunner` and `rake lookbook:server_and_test`; `Runner#output` injection.
- **Changed:** `copy_to_clipboard` defaults to `false`; `automatic_run` parsed as boolean; auto-run hook now uses the Ferrum `Runner`; `lookbook:approve` matches namespaced previews by exact base name or `_suffix`.

- [ ] **Step 5: Run the full suite**

```bash
bundle exec rspec
```

Expected: All unit specs pass; the Ferrum/Chrome integration spec may fail in headless environments without Chrome (allowed).

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: update README and CHANGELOG for hardening changes"
```

---

## Self-Review Checklist

- [ ] **Spec coverage:** Every hardening issue is mapped:
  - ImageMagick removal → Tasks 4 & 5.
  - `cuprite`/legacy code removal + auto-run rewiring → Task 3.
  - Auth mocking → Task 6.
  - `$stdout` thread-safety → Tasks 5 & 7.
  - Running server requirement → Task 8.
  - Namespaced approval → Task 9.
  - `rubocop` test-env crash → Task 2.
  - Lookbook 1.x fallback removal → Tasks 5, 6, 7.
  - Dead `BaselineManager` → Task 3.
- [ ] **Placeholder scan:** No `TBD`, `TODO`, or vague requirements. Every step includes concrete file paths or code.
- [ ] **Type consistency:** `preview_checker_setup` is consistently a callable/`nil`. `Runner` output is consistently an IO-like object. Approval uses `Pathname` relative paths consistently. `ServerTestRunner` uses the same `config.lookbook_host` string everywhere.
- [ ] **Deletion safety:** Legacy files are only deleted after their references are removed from `lib/lookbook_visual_tester.rb` and `UpdatePreviews`/`Railtie` are rewired (Task 3 ordering).
- [ ] **Test cycle:** Every task ends with a `bundle exec rspec` run for new/changed specs. The Ferrum/Chrome integration spec is an explicitly-allowed environmental failure.
- [ ] **Driver thread-safety:** `record_mismatch` reads the per-thread driver via `Thread.current[:lookbook_visual_tester_driver]`, set in `run_scenario`, so concurrent runs do not share a driver reference.

---

## Execution Handoff

**Plan saved to:** `docs/superpowers/plans/2026-08-09-lookbook-visual-tester-hardening.md`

Suggested execution order:

1. Run the full test suite as a baseline: `bundle exec rspec`. (Note: before Task 2 this may segfault on Ruby 3.4 due to `rubocop`/`racc`; that is expected and fixed by Task 2.)
2. Work through Tasks 1 → 10 in order. Each task is independently reviewable and ends with a green test run (except the allowed Ferrum/Chrome integration spec).
3. After Task 10, do a final `bundle exec rspec` and confirm the CHANGELOG is accurate.

Once the gem is hardened, the CaptainTandem integration (initializer, `config/lookbook.rb`, `preview_checker_setup` providing `Current.user`, wrapper task, baseline git workflow) can be written so agents can run it end-to-end.
