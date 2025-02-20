require "lookbook_visual_tester/session_manager"

module LookbookVisualTester
  class ScreenshotTaker
    attr_reader :session, :logger

    def initialize(logger: Kernel)
      @session = SessionManager.instance.session
      @logger = logger
    end

    def capture(preview_url, path)
      visit_preview(preview_url)
      save_screenshot(path)
    end

    private

    def visit_preview(preview_url)
      session.visit(preview_url)
      session.assert_selector("body", wait: 10)
    rescue StandardError => e
      logger.puts "    Error visiting URL: #{e.message}"
      raise e
    end

    def save_screenshot(path)
      session.save_screenshot(path)
      logger.puts "    Screenshot saved to #{path}"
    end
  end
end
