require 'capybara'
require 'capybara/cuprite'

module LookbookVisualTester
  module CapybaraSetup
    @setup_complete = false

    def self.setup
      return if @setup_complete

      Capybara.register_driver :cuprite do |app|
        Capybara::Cuprite::Driver.new(
          app,
          window_size: [1400, 1400],
          timeout: 20,
          process_timeout: 20,
          headless: true,
          browser_options: { 'ignore-certificate-errors' => true }
        )
      end

      Capybara.default_driver = :cuprite
      Capybara.default_max_wait_time = 15
      Capybara.server = :puma, { Silent: true }

      @setup_complete = true
    end
  end
end
