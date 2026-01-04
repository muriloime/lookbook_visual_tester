require 'lookbook'
require 'json'
require_relative 'configuration'
require_relative 'scenario_run'
require_relative 'services/image_comparator'
require_relative 'drivers/ferrum_driver'
require_relative 'variant_resolver'

module LookbookVisualTester
  class Runner
    Result = Struct.new(:scenario_name, :status, :mismatch, :diff_path, :error, :baseline_path,
                        :current_path, keyword_init: true)

    def initialize(config = LookbookVisualTester.config, pattern: nil)
      @config = config
      @pattern = pattern
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

      puts "Found #{previews.count} previews matching '#{@pattern}'."
      puts "Running against #{@variants.size} variant(s)."

      @variants.each do |variant_input|
        resolver = VariantResolver.new(variant_input)
        variant_options = resolver.resolve
        variant_slug = resolver.slug
        width = resolver.width_in_pixels

        puts "  Variant: #{variant_slug.presence || 'Default'}"

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
        puts 'Invalid JSON in VARIANTS env var. Defaulting to standard run.'
        [{}]
      end
    end

    def run_sequentially(previews, variant_slug, variant_options, width)
      previews.each do |preview|
        group = preview.respond_to?(:scenarios) ? preview.scenarios : preview.examples
        group.each do |scenario|
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
        group = preview.respond_to?(:scenarios) ? preview.scenarios : preview.examples
        group.each do |scenario|
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

      # Zip results from this concurrent batch into results
      # Note: This aggregates results per variant loop.
      @results.concat(Concurrent::Promises.zip(*promises).value)
      pool.shutdown
      pool.wait_for_termination
    end

    def init_driver_pool
      count = @config.threads > 1 ? @config.threads : 1
      count.times do
        @driver_pool << LookbookVisualTester::Drivers::FerrumDriver.new(@config)
      end
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
      puts "Running visual test for: #{run_data.name} #{variant_slug.present? ? "[#{variant_slug}]" : ''}"

      begin
        driver_width = width || 1280
        driver.resize_window(driver_width, 800)
        driver.visit(run_data.preview_url)

        # Determine paths
        current_path = run_data.current_path
        baseline_path = run_data.baseline_path
        diff_path = @config.diff_dir.join(run_data.diff_filename)
        # Update diff path to respect variant structure if needed?
        # Actually ScenarioRun#diff_filename is just flat for now but let's fix that?
        # ScenarioRun doesn't expose diff_path with slug. Let's fix that manually here if needed or update ScenarioRun.
        # Wait, ScenarioRun stores baseline/current in folders but diff_filename is just name.
        # We should probably put diffs in folders too.
        # Let's adjust diff_path here:
        if variant_slug.present?
          diff_path = @config.diff_dir.join(variant_slug, run_data.diff_filename)
        end

        FileUtils.mkdir_p(File.dirname(current_path))
        FileUtils.mkdir_p(File.dirname(diff_path))

        driver.save_screenshot(current_path.to_s)

        # Trimming (Feature parity with legacy ScreenshotTaker)
        if File.exist?(current_path)
          system("convert #{current_path} -trim -bordercolor white -border 10x10 #{current_path}")
        end

        comparator = LookbookVisualTester::ImageComparator.new(
          baseline_path.to_s,
          current_path.to_s,
          diff_path.to_s
        )

        result = comparator.call

        status = :passed
        mismatch = 0.0
        error = nil

        if result[:error]
          if result[:error] == 'Baseline not found'
            # First run, maybe auto-approve or just report
            puts '  [NEW] Baseline not found. Saved current as potential baseline.'
            FileUtils.mkdir_p(File.dirname(baseline_path))
            FileUtils.cp(current_path, baseline_path)
            status = :new
          else
            puts "  [ERROR] #{result[:error]}"
            status = :error
            error = result[:error]
          end
        elsif result[:mismatch] > 0
          mismatch = result[:mismatch]
          puts "  [FAIL] Mismatch: #{mismatch.round(2)}%. Diff saved to #{diff_path}"
          status = :failed

          # Clipboard (Feature parity with legacy ScreenshotTaker)
          if @config.copy_to_clipboard
            system("xclip -selection clipboard -t image/png -i #{current_path}")
          end
        else
          puts '  [PASS] Identical.'
          status = :passed
        end

        Result.new(
          scenario_name: run_data.name,
          status: status,
          mismatch: mismatch,
          diff_path: diff_path.to_s,
          error: error,
          baseline_path: baseline_path.to_s,
          current_path: current_path.to_s
        )
      rescue StandardError => e
        puts "  [ERROR] Exception: #{e.message}"
        puts e.backtrace.take(5)
        Result.new(
          scenario_name: run_data.name,
          status: :error,
          error: e.message,
          baseline_path: run_data.baseline_path.to_s,
          current_path: run_data.current_path.to_s
        )
      end
    end
  end
end
