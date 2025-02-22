require 'lookbook_visual_tester/session_manager'
require 'lookbook_visual_tester/service'

require 'fileutils'

module LookbookVisualTester
  class ScreenshotTaker < Service
    attr_reader :preview_url, :path, :crop, :logger

    CLIPBOARD = 'clipboard'

    def initialize(preview_url, path = CLIPBOARD, crop: true, logger: Rails.logger)
      @preview_url = preview_url
      @path = path
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
        save_to_clipboard
      else
        save_printscreen
      end
      # Additional wait for any JavaScript animations
      sleep 1
    rescue StandardError => e
      logger.puts "Error capturing screenshot for #{preview_url}: #{e.message}"
      raise e
    end

    def save_to_clipboard(path = @path)
      system("xclip -selection clipboard -t image/png -i #{path}")
    end

    private

    def print_and_save_to_clipboard
      Tempfile.create(['screenshot', '.png']) do |file|
        save_printscreen(file.path)
        save_to_clipboard(file.path)
      end
    end

    def save_printscreen(path = @path)
      session.save_screenshot(path)

      # remove white space
      system("convert #{path} -trim -bordercolor white -border 10x10 #{path}") if crop

      logger.info "    Screenshot saved to #{path}"
    end
  end
end
