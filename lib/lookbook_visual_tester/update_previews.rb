require_relative 'service'
require_relative 'screenshot_taker'

module LookbookVisualTester
  class UpdatePreviews < Service
    attr_reader :app, :changes

    def initialize(app, changes)
      @app = app
      @changes = changes[:modified]
      @changes_hash = changes
    end

    def update_app_data
      app.data.last_changed_files = changes.presence || []
      app.data.last_changed_previews = previews
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

    def clean_file_name(file)
      '/' + file.split('/')[-1].split('.')[0]
    end

    def selected_previews
      @selected_previews ||= Lookbook.previews.select do |preview|
        selected_changes.any? { |file| preview.file_path.to_s.include?(clean_file_name(file)) }
      end
    end

    def process_changes
      Rails.logger.info "LookbookVisualTester: previews #{selected_previews.count}"
      selected_previews.each do |preview|
        Rails.logger.info "LookbookVisualTester: entering #{preview.inspect}"

        preview.scenarios.each do |scenario|
          scenario_run = LookbookVisualTester::ScenarioRun.new(scenario)
          Rails.logger.info "LookbookVisualTester: Processing scenario #{scenario_run.inspect}"
          LookbookVisualTester::ScreenshotTaker.call(scenario_run:, app:)
        end
      end
    end
  end
end
