require 'lookbook_visual_tester/configuration'

module LookbookVisualTester
  class ScenarioRun
    attr_reader :scenario, :preview, :variant_slug, :display_params

    def initialize(scenario, variant_slug: nil, display_params: {})
      @scenario = scenario
      @preview = scenario.preview
      @variant_slug = variant_slug
      @display_params = display_params

      LookbookVisualTester.config.logger.info "  Scenario: #{scenario_name} #{variant_suffix}"
    end

    def preview_name
      preview.name.underscore.gsub('/', '_')
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
      base = LookbookVisualTester.config.current_dir
      base = base.join(variant_slug) if variant_slug.present?
      base.join(filename)
    end

    def baseline_path
      base = LookbookVisualTester.config.baseline_dir
      base = base.join(variant_slug) if variant_slug.present?
      base.join(filename)
    end

    def preview_url
      params = { path: preview.lookup_path + '/' + scenario.name }

      if display_params.any?
        # Transform display_params { theme: 'dark' } -> { _display: { theme: 'dark' } }
        params[:_display] = display_params
      end

      Lookbook::Engine.routes.url_helpers.lookbook_preview_url(
        params.merge(host: LookbookVisualTester.config.lookbook_host)
      )
    end

    private

    def variant_suffix
      variant_slug.present? ? "[#{variant_slug}]" : ''
    end
  end
end
