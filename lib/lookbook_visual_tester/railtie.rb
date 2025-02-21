# lib/lookbook_visual_tester/railtie.rb

require "lookbook_visual_tester/capybara_setup"
require "lookbook_visual_tester/update_previews"

module LookbookVisualTester
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "tasks/lookbook_visual_tester.rake"
    end

    initializer "LookbookVisualTester.lookbook_after_change" do |app1|
      puts " >>>>> lookbook_after_change initialized: #{app1.inspect}"
      Lookbook.after_change do |app, changes|
        LookbookVisualTester::UpdatePreviews.call(app, changes)
      end
    end
  end
end
