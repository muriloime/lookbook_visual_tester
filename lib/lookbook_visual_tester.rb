# frozen_string_literal: true

# lib/lookbook_visual_tester.rb

require_relative 'lookbook_visual_tester/version'
require_relative 'lookbook_visual_tester/railtie' if defined?(Rails)

module LookbookVisualTester
  class Error < StandardError; end
  # Your code goes here...
end
