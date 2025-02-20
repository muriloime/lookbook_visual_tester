# lib/tasks/lookbook_visual_tester.rake

require "capybara"
require "capybara/cuprite"
require "fileutils"
require "mini_magick"

require "lookbook_visual_tester/report_generator"
require "lookbook_visual_tester/screenshot_taker"

namespace :lookbook_visual_tester do
  desc "Run visual regression tests for Lookbook previews"
  task run: :environment do
    screenshot_taker = LookbookVisualTester::ScreenshotTaker.new

    # Directories for screenshots
    base_path = Rails.root.join("spec/visual_screenshots")
    baseline_dir = base_path.join("baseline")
    current_dir = base_path.join("current_run")
    diff_dir = base_path.join("diff")

    [baseline_dir, current_dir, diff_dir].each do |dir|
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end

    # Enumerate Lookbook previews
    previews = Lookbook.previews

    if previews.empty?
      puts "No Lookbook previews found."
      exit
    end

    previews[..5].each do |preview|
      preview_name = preview.name.underscore
      puts "Processing Preview: #{preview_name}"

      preview.scenarios[..5].each do |scenario|
        scenario_name = scenario.name.underscore
        puts "  Scenario: #{scenario_name}"

        # Define screenshot paths
        filename = "#{preview_name}_#{scenario_name}.png"
        current_path = current_dir.join(filename)
        baseline_path = baseline_dir.join(filename)
        diff_path = diff_dir.join("#{preview_name}_#{scenario_name}_diff.png")

        # Generate preview URL
        # binding.pry
        preview_url = Lookbook::Engine.routes.url_helpers.lookbook_preview_url(
          # preview: preview.name,
          path: preview.lookup_path + "/" + scenario.name,
          # scenario: scenario.name,
          host: ENV["LOOKBOOK_HOST"] || "https://localhost:5000"
        )

        screenshot_taker.capture(preview_url, current_path)

        puts "    Visiting URL: #{preview_url}"

        # Compare with baseline if it exists
        if baseline_path.exist?
          baseline_image = MiniMagick::Image.open(baseline_path)
          current_image = MiniMagick::Image.open(current_path)

          # Ensure images are the same dimensions
          unless baseline_image.dimensions == current_image.dimensions
            puts "    Image dimensions do not match. Skipping comparison."
            next
          end

          # Compare images using ImageMagick's compare
          begin
            compare_command = "compare -metric AE \"#{baseline_path}\" \"#{current_path}\" \"#{diff_path}\" 2>&1"
            result = `#{compare_command}`
            distortion = result.strip.to_i

            if distortion > 0
              puts "    Differences found! Diff image saved to #{diff_path}"
            else
              puts "    No differences detected."
              # Remove diff image if exists
              File.delete(diff_path) if diff_path.exist?
            end
          rescue StandardError => e
            puts "    Error comparing images: #{e.message}"
          end
        else
          # If no baseline exists, copy current to baseline
          FileUtils.cp(current_path, baseline_path)
          puts "    Baseline image created at #{baseline_path}"
        end
      end
    end

    # Generate HTML report
    report = LookbookVisualTester::ReportGenerator.new(baseline_dir, current_dir, diff_dir, base_path)
    report_path = report.generate
    puts "Visual regression report generated at #{report_path}"
  end

  desc "Update baseline screenshots with current_run screenshots"
  task update_baseline: :environment do
    base_path = Rails.root.join("spec/visual_screenshots")
    baseline_dir = base_path.join("baseline")
    current_dir = base_path.join("current_run")

    unless current_dir.exist?
      puts "Current run directory does not exist. Run the visual regression tests first."
      exit
    end

    Dir.glob(current_dir.join("*.png")).each do |current_file|
      filename = File.basename(current_file)
      baseline_file = baseline_dir.join(filename)
      FileUtils.cp(current_file, baseline_file)
      puts "Baseline updated for #{filename}"
    end
  end
end
