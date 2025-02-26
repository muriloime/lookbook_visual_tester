require 'lookbook_visual_tester/session_manager'
require 'lookbook_visual_tester/service'

require 'fileutils'

module LookbookVisualTester
  class ScreenshotTaker < Service
    attr_reader :scenario_run, :path, :crop, :logger

    CLIPBOARD = 'clipboard'

    delegate :preview_url, to: :scenario_run

    def initialize(scenario_run:,
                   path: nil,
                   crop: true,
                   logger: Rails.logger)
      @scenario_run = scenario_run
      @path = path || File.join(LookbookVisualTester.config.current_dir, scenario_run.filename)
      @crop = crop
      @logger = logger
    end

    def session
      @session ||= SessionManager.instance.session
    end

    def call
      FileUtils.mkdir_p(File.dirname(path))

      session.visit(preview_url)

      # Wait for network requests to complete
      # session.driver.network_idle?

      # # Wait for any loading indicators to disappear
      # begin
      #   session.has_no_css?(".loading", wait: 10)
      # rescue StandardError
      #   nil
      # end
      if path == CLIPBOARD
        print_and_save_to_clipboard
      else
        save_printscreen
      end
      # Additional wait for any JavaScript animations
      sleep 1
    rescue StandardError => e
      logger.info "Error capturing screenshot for #{preview_url}: #{e.message}"
      raise e
    end

    def save_to_clipboard(path = @path)
      system("xclip -selection clipboard -t image/png -i #{path}")
    end

    private

    def print_and_save_to_clipboard
      Tempfile.create(['screenshot', '.png']) do |file|
        save_printscreen(file.path)
        # save_to_clipboard(file.path)
      end
    end

    def save_printscreen(path = @path)
      session.save_screenshot(path)

      system("convert #{path} -trim -bordercolor white -border 10x10 #{path}") if crop

      if different_from_baseline?(path)
        save_to_clipboard(path) if LookbookVisualTester.config.copy_to_clipboard

        save_to_last_modified(path)
        save_to_history(path)
        LookbookVisualTester.data[:last_changed_screenshot] ||= {}
        LookbookVisualTester.data[:last_changed_screenshot][scenario_run.preview_name] =
          history_path
      end

      clean_old_history
      logger.info "Screenshot saved to #{path}"
    end

    def different_from_baseline?(current_path)
      baseline_path = File.join(LookbookVisualTester.config.baseline_dir, scenario_run.filename)
      return true unless File.exist?(baseline_path)

      system("compare -metric AE #{current_path} #{baseline_path} null: 2>&1") != '0'
    end

    def clean_old_history(keep: LookbookVisualTester.config.history_keep_last_n)
      history_files = Dir.glob(File.join(LookbookVisualTester.config.history_dir,
                                         "#{scenario_run.preview_name}_*.png"))
      history_files.sort_by! { |f| File.mtime(f) }
      history_files[0...-keep].each { |f| File.delete(f) }
    end

    def save_to_history(current_path)
      @history_path = File.join(
        LookbookVisualTester.config.history_dir,
        scenario_run.timestamp_filename
      )
      FileUtils.cp(current_path, history_path)
    end

    def save_to_last_modified(current_path)
      last_path = File.join(
        LookbookVisualTester.config.current_dir,
        'last.png'
      )
      FileUtils.cp(current_path, last_path)
    end

    attr_reader :history_path
  end
end
