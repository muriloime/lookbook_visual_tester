# lib/lookbook_visual_tester/railtie.rb

require "lookbook_visual_tester/capybara_setup"

module LookbookVisualTester
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "tasks/lookbook_visual_tester.rake"
    end
  end
end
