require "capybara"
require "capybara/cuprite"

module LookbookVisualTester
  module CapybaraSetup
    def self.setup
      Capybara.register_driver :cuprite do |app|
        Capybara::Cuprite::Driver.new(app, headless: true)
      end

      Capybara.default_driver = :cuprite
      Capybara.server = :puma, { Silent: true }
    end
  end
end
