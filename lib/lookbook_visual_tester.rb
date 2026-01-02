# frozen_string_literal: true

# lib/lookbook_visual_tester.rb

require_relative 'lookbook_visual_tester/version'
require_relative 'lookbook_visual_tester/configuration'
require_relative 'lookbook_visual_tester/railtie' if defined?(Rails)
require_relative 'lookbook_visual_tester/scenario_finder'
require_relative 'lookbook_visual_tester/store'
require_relative 'lookbook_visual_tester/runner'
require_relative 'lookbook_visual_tester/driver'
require_relative 'lookbook_visual_tester/drivers/ferrum_driver'
require_relative 'lookbook_visual_tester/services/image_comparator'

module LookbookVisualTester
  class Error < StandardError; end

  def self.configure
    yield(config)
  end
end
