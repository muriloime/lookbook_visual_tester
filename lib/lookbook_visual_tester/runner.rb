require 'lookbook'
require_relative 'configuration'
require_relative 'scenario_run'
require_relative 'services/image_comparator'
require_relative 'drivers/ferrum_driver'

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

      if @config.threads > 1
        run_concurrently(previews)
      else
        run_sequentially(previews)
      end

      @results
    ensure
      cleanup_drivers
    end

    private

    def run_sequentially(previews)
      previews.each do |preview|
        group = preview.respond_to?(:scenarios) ? preview.scenarios : preview.examples
        group.each do |scenario|
          driver = checkout_driver
          begin
            @results << run_scenario(scenario, driver)
          ensure
            return_driver(driver)
          end
        end
      end
    end

    def run_concurrently(previews)
      require 'concurrent-ruby'
      pool = Concurrent::FixedThreadPool.new(@config.threads)
      promises = []

      previews.each do |preview|
        group = preview.respond_to?(:scenarios) ? preview.scenarios : preview.examples
        group.each do |scenario|
          promises << Concurrent::Promises.future_on(pool) do
            driver = checkout_driver
            begin
              run_scenario(scenario, driver)
            ensure
              return_driver(driver)
            end
          end
        end
      end

      @results = Concurrent::Promises.zip(*promises).value
      pool.shutdown
      pool.wait_for_termination
    end

    def init_driver_pool
      # Create N drivers where N = threads
      # If sequential, we only need 1, but we can just simplify and create as many as updated threads config says
      # Or just 1 if not concurrent?
      # Actually, let's just stick to @config.threads.
      # Even for sequential run, if threads was configured to 4, we might create 4 but only use 1.
      # Optimization: if sequential, only create 1.

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

    def run_scenario(scenario, driver)
      run_data = ScenarioRun.new(scenario)
      puts "Running visual test for: #{run_data.name}"

      begin
        driver.resize_window(1280, 800) # Default or config
        driver.visit(run_data.preview_url)

        # Determine paths
        current_path = run_data.current_path
        baseline_path = run_data.baseline_path
        diff_path = @config.diff_dir.join(run_data.diff_filename)

        FileUtils.mkdir_p(File.dirname(current_path))

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
