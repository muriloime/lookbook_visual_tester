module LookbookVisualTester
  class BaselineManager < Service
    attr_reader :preview_name, :scenario_name

    def initialize(preview_name:, scenario_name:)
      @preview_name = preview_name
      @scenario_name = scenario_name
    end

    def self.update_baseline_if_approved(preview_name:, scenario_name:)
      new(preview_name:, scenario_name:).update_baseline_if_approved
    end

    def update_baseline_if_approved
      return false unless last_screenshot_path

      FileUtils.cp(
        last_screenshot_path,
        File.join(LookbookVisualTester.config.baseline_dir, scenario_path)
      )
      true
    end

    private

    def last_screenshot_path
      LookbookVisualTester.data[:last_changed_screenshot]&.[](preview_name)
    end

    def scenario_path
      "#{preview_name}/#{scenario_name}.png"
    end
  end
end
