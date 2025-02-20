require "lookbook_visual_tester/session_manager"
require "capybara/cuprite"
require "fileutils"

module LookbookVisualTester
  class ScreenshotTaker
    attr_reader :session, :logger

    def initialize(logger: Kernel)
      Capybara.register_driver :cuprite do |app|
        Capybara::Cuprite::Driver.new(
          app,
          window_size: [1400, 1400],
          browser_options: { "ignore-certificate-errors" => nil },
          timeout: 20,
          process_timeout: 20
        )
      end

      Capybara.default_driver = :cuprite
      Capybara.default_max_wait_time = 15
      @session = Capybara::Session.new(:cuprite)
      @logger = logger
    end

    def capture(preview_url, path)
      FileUtils.mkdir_p(File.dirname(path))

      session.visit(preview_url)

      # Wait for network requests to complete
      # session.driver.network_idle?

      # Wait for any loading indicators to disappear
      begin
        session.has_no_css?(".loading", wait: 10)
      rescue StandardError
        nil
      end

      # Additional wait for any JavaScript animations
      sleep 1

      save_screenshot(path)
    rescue StandardError => e
      logger.puts "Error capturing screenshot for #{preview_url}: #{e.message}"
      raise e
    end

    private

    def save_screenshot(path)
      session.save_screenshot(path)
      logger.puts "    Screenshot saved to #{path}"
    end
  end
end
