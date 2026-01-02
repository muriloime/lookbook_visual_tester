# lib/lookbook_visual_tester/railtie.rb

# require 'lookbook_visual_tester/capybara_setup'
require 'lookbook_visual_tester/update_previews'

module LookbookVisualTester
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load 'tasks/lookbook_visual_tester.rake'
    end

    initializer 'LookbookVisualTester.lookbook_after_change' do |_app|
      Rails.logger.info "LookbookVisualTester initialized with host: #{LookbookVisualTester.config.lookbook_host}"
      Lookbook.after_change do |app, changes|
        next unless LookbookVisualTester.config.automatic_run

        # get hash of content of modified files to see if has changed
        modified = changes[:modified]
        my_hash = modified.sort.map { |f| File.read(f) }.hash

        lock_file = Rails.root.join('tmp', 'lookbook_visual_tester.lock')
        Rails.logger.info ">>> LookbookVisualTester: No changes detected in #{LookbookVisualTester.data}"

        # Rails.logger.info ">>> LookbookVisualTester: Stack trace: #{caller.join("\n")}"
        Rails.logger.info ">>> LookbookVisualTester: Changes in #{Rails.cache.instance_variable_get(:@data).keys.inspect}"
        File.open(lock_file, 'w') do |file|
          if file.flock(File::LOCK_EX | File::LOCK_NB)
            if LookbookVisualTester.data[:last_hash] == my_hash
              Rails.logger.info 'LookbookVisualTester: No changes detected in Lookbook'
            else
              LookbookVisualTester.data[:last_hash] = my_hash
              Rails.logger.info "LookbookVisualTester: Running UpdatePreviews, updattin to #{LookbookVisualTester.data.inspect}"
              LookbookVisualTester::UpdatePreviews.call(changes)
            end
            file.flock(File::LOCK_UN)
            Rails.logger.info 'LookbookVisualTester: UpdatePreviews File unlocked.'
          else
            Rails.logger.info 'LookbookVisualTester: UpdatePreviews already running, skipping this call.'
          end
        end
      end
    end
  end
end
