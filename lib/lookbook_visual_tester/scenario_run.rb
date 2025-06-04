require 'lookbook_visual_tester/configuration'

module LookbookVisualTester
  class ScenarioRun
    attr_reader :scenario, :preview

    def initialize(scenario)
      @scenario = scenario
      @preview = scenario.preview

      LookbookVisualTester.config.logger.info "  Scenario: #{scenario_name}"
    end

    def preview_name
      preview.name.underscore
    end

    def scenario_name
      scenario.name.underscore
    end

    def name
      "#{preview_name}_#{scenario_name}"
    end

    def filename
      "#{name}.png"
    end

    def timestamp_filename
      @timestamp_filename ||= begin
        timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
        "#{name}_#{timestamp}.png"
      end
    end

    def diff_filename
      "#{preview_name}_#{scenario_name}_diff.png"
    end

    def current_path
      LookbookVisualTester.config.current_dir.join(filename)
    end

    def baseline_path
      LookbookVisualTester.config.baseline_dir.join(filename)
    end

    def preview_url
      Lookbook::Engine.routes.url_helpers.lookbook_preview_url(
        path: preview.lookup_path + '/' + scenario.name,
        host: LookbookVisualTester.config.lookbook_host
      )
    end
  end
end
