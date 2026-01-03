require 'spec_helper'
require 'fileutils'

RSpec.describe 'Full Flow Integration' do
  let(:reference_dir) { Rails.root.join('spec', 'lookbook_visual_tester', 'reference') }
  let(:diff_dir) { Rails.root.join('spec', 'lookbook_visual_tester', 'diffs') }

  before do
    # Clean up previous runs
    FileUtils.rm_rf(Rails.root.join('spec', 'lookbook_visual_tester'))

    # Start server
    require 'capybara'
    Capybara.app = Rails.application
    server = Capybara::Server.new(Rails.application)
    server.boot

    # Configure the gem
    LookbookVisualTester.configure do |config|
      config.base_path = reference_dir
      config.lookbook_host = "http://#{server.host}:#{server.port}"
    end
  end

  it 'runs the visual tester and generates screenshots' do
    # Initialize the runner
    runner = LookbookVisualTester::Runner.new

    # Run the tests
    # Note: Ferrum might need some time to launch
    expect { runner.run }.not_to raise_error

    # Check if screenshots were created
    current_dir = LookbookVisualTester.config.current_dir

    expect(File.exist?(current_dir.join('example_default.png'))).to be true
    expect(File.exist?(current_dir.join('example_with_long_title.png'))).to be true
  end
end
