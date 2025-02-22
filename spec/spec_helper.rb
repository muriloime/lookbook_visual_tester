require 'bundler/setup'
require 'lookbook_visual_tester'
require 'lookbook'
require_relative 'support/rails_mock_helper'

# Require support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Enable expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed

  config.include RailsMockHelper

  config.before(:suite) do
    RailsMockHelper.mock_rails_logger
  end
end
