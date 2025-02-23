# lib/lookbook_visual_tester/railtie.rb

require 'lookbook_visual_tester/capybara_setup'
require 'lookbook_visual_tester/update_previews'

module LookbookVisualTester
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load 'tasks/lookbook_visual_tester.rake'
    end

    config.after_initialize do
      Rails.logger.info "LookbookVisualTester initialized with host: #{LookbookVisualTester.config.lookbook_host}"
      Lookbook.after_change do |app, changes|
        LookbookVisualTester::UpdatePreviews.call(app, changes)
      end
    end
  end
end
