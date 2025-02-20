require "lookbook_visual_tester/session_manager"
require "capybara/cuprite"
require "fileutils"

module LookbookVisualTester
  class ScreenshotTaker
    attr_reader :session, :logger

    CLIPBOARD = 'clipboard'

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

    def capture(preview_url, path = CLIPBOARD)
      FileUtils.mkdir_p(File.dirname(path))

      session.visit(preview_url)

      # Wait for network requests to complete
      # session.driver.network_idle?

      # Additional wait for any JavaScript animations
      sleep 1
      if path == CLIPBOARD
        save_to_clipboard
      else
        save_screenshot(path)
      end
    rescue StandardError => e
      logger.puts "Error capturing screenshot for #{preview_url}: #{e.message}"
      raise e
    end

    private
    def save_to_clipboard
      Tempfile.create(['screenshot', '.png']) do |file|
        session.save_screenshot(file.path)

        # Example: Copy to clipboard (Linux xclip)
        system("xclip -selection clipboard -t image/png -i #{file.path}")
      end
    end

    def save_screenshot(path)
      session.save_screenshot(path)
      logger.puts "    Screenshot saved to #{path}"
    end
  end
end
