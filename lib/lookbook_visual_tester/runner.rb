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
          handle_missing_baseline(run_data, paths)
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

    def handle_missing_baseline(run_data, paths)
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

    # Resolves the driver for the current scenario thread, set in run_scenario.
    def driver
      Thread.current[:lookbook_visual_tester_driver]
    end
  end
end
