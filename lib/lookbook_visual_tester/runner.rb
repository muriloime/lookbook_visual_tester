require 'lookbook'
require_relative 'configuration'
require_relative 'scenario_run'
require_relative 'services/image_comparator'
require_relative 'drivers/ferrum_driver'

module LookbookVisualTester
  class Runner
    def initialize(config = LookbookVisualTester.config)
      @config = config
      @driver = init_driver
    end

    def run
      # Iterate all previews
      # Lookbook::Engine.previews might need to be refreshed or loaded
      previews = Lookbook.previews

      puts "Found #{previews.count} previews."

      previews.each do |preview|
        preview.scenarios.each do |scenario|
          run_scenario(scenario)
        end
      end
    ensure
      @driver.cleanup if @driver
    end

    private

    def init_driver
      adapter = @config.driver_adapter
      case adapter
      when :ferrum
        LookbookVisualTester::Drivers::FerrumDriver.new(@config)
      else
        # For now only Ferrum is implemented fully in this phase
        LookbookVisualTester::Drivers::FerrumDriver.new(@config)
      end
    end

    def run_scenario(scenario)
      run_data = ScenarioRun.new(scenario)
      puts "Running visual test for: #{run_data.name}"

      begin
        @driver.resize_window(1280, 800) # Default or config
        @driver.visit(run_data.preview_url)

        # Determine paths
        current_path = run_data.current_path
        baseline_path = run_data.baseline_path
        diff_path = @config.diff_dir.join(run_data.diff_filename)

        FileUtils.mkdir_p(File.dirname(current_path))

        @driver.save_screenshot(current_path.to_s)

        comparator = LookbookVisualTester::ImageComparator.new(
          baseline_path.to_s,
          current_path.to_s,
          diff_path.to_s
        )

        result = comparator.call

        if result[:error]
            if result[:error] == "Baseline not found"
                # First run, maybe auto-approve or just report
                puts "  [NEW] Baseline not found. Saved current as potential baseline."
            else
                puts "  [ERROR] #{result[:error]}"
            end
        elsif result[:mismatch] > 0
          puts "  [FAIL] Mismatch: #{result[:mismatch].round(2)}%. Diff saved to #{diff_path}"
        else
          puts "  [PASS] Identical."
        end
      rescue StandardError => e
        puts "  [ERROR] Exception: #{e.message}"
        puts e.backtrace.take(5)
      end
    end
  end
end
