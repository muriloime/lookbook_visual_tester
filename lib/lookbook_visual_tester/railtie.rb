# lib/lookbook_visual_tester/railtie.rb

module LookbookVisualTester
  class Railtie < ::Rails::Railtie
    rake_tasks do
      path = File.expand_path('../tasks/lookbook_visual_tester.rake', __dir__)
      load path
    end

    initializer 'LookbookVisualTester.lookbook_after_change' do |_app|
      Rails.logger.info "LookbookVisualTester initialized with host: #{LookbookVisualTester.config.lookbook_host}"
      Lookbook.after_change do |_app, changes|
        next unless LookbookVisualTester.config.automatic_run

        modified = changes[:modified]
        my_hash = modified.sort.map { |f| File.read(f) }.hash

        lock_file = Rails.root.join('tmp', 'lookbook_visual_tester.lock')
        Rails.logger.info ">>> LookbookVisualTester: No changes detected in #{LookbookVisualTester.data}"

        File.open(lock_file, 'w') do |file|
          if file.flock(File::LOCK_EX | File::LOCK_NB)
            if LookbookVisualTester.data[:last_hash] == my_hash
              Rails.logger.info 'LookbookVisualTester: No changes detected in Lookbook'
            else
              LookbookVisualTester.data[:last_hash] = my_hash
              Rails.logger.info "LookbookVisualTester: Running UpdatePreviews, updating to #{LookbookVisualTester.data.inspect}"
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
