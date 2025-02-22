# Setup Capybara
require 'singleton'
require 'capybara'
require 'capybara/cuprite'

module LookbookVisualTester
  class SessionManager
    include Singleton

    def initialize
      CapybaraSetup.setup
      @session = Capybara::Session.new(:cuprite)
    end

    attr_reader :session
  end
end
