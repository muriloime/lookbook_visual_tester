require 'lookbook_visual_tester/session_manager'
require 'lookbook_visual_tester/service'

require 'fileutils'

module LookbookVisualTester
  class ScreenshotTaker < Service
    attr_reader :session, :logger

    CLIPBOARD = 'clipboard'

    def initialize(logger: Rails.logger)
      @session = SessionManager.instance.session
      @logger = logger
    end

    def capture(preview_url, path = CLIPBOARD, crop: true)
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
        save_to_clipboard(crop:)
      else
        save_printscreen(path:, crop:)
      end
      # Additional wait for any JavaScript animations
      sleep 1
    rescue StandardError => e
      logger.puts "Error capturing screenshot for #{preview_url}: #{e.message}"
      raise e
    end

    private

    def save_to_clipboard(crop: false)
      Tempfile.create(['screenshot', '.png']) do |file|
        session.save_screenshot(file.path, crop:)

        system("xclip -selection clipboard -t image/png -i #{file.path}")
      end
    end

    def save_printscreen(path: nil, crop: false)
      session.save_screenshot(path)

      # remove white space
      system("convert #{path} -trim -bordercolor white -border 10x10 #{path}") if crop

      logger.info "    Screenshot saved to #{path}"
    end
  end
end
