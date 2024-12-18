# lib/tasks/lookbook_visual_tester.rake

require "capybara"
require "capybara/cuprite"
require "fileutils"
require "mini_magick"

namespace :lookbook_visual_tester do
  desc "Run visual regression tests for Lookbook previews"
  task run: :environment do
    # Setup Capybara
    LookbookVisualTester::CapybaraSetup.setup
    session = Capybara::Session.new(:cuprite)

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

    previews.each do |preview|
      preview_name = preview.name.underscore
      puts "Processing Preview: #{preview_name}"

      preview.scenarios.each do |scenario|
        scenario_name = scenario.name.underscore
        puts "  Scenario: #{scenario_name}"

        # Generate preview URL
        # binding.pry
        preview_url = Lookbook::Engine.routes.url_helpers.lookbook_preview_url(
          # preview: preview.name,
          path: preview.lookup_path + "/" + scenario.name,
          # scenario: scenario.name,
          host: ENV["LOOKBOOK_HOST"] || "localhost:3000"
        )

        puts "    Visiting URL: #{preview_url}"

        # Visit the preview URL
        begin
          session.visit(preview_url)
        rescue StandardError => e
          puts "    Error visiting URL: #{e.message}"
          next
        end

        # Define screenshot paths
        filename = "#{preview_name}_#{scenario_name}.png"
        current_path = current_dir.join(filename)
        baseline_path = baseline_dir.join(filename)
        diff_path = diff_dir.join("#{preview_name}_#{scenario_name}_diff.png")

        # Save current screenshot
        session.save_screenshot(current_path)
        puts "    Screenshot saved to #{current_path}"

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
    generate_report(baseline_dir, current_dir, diff_dir, base_path)
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

  def generate_report(baseline_dir, current_dir, diff_dir, base_path)
    report_path = base_path.join("report.html")
    File.open(report_path, "w") do |file|
      file.puts "<!DOCTYPE html>"
      file.puts "<html lang='en'>"
      file.puts "<head><meta charset='UTF-8'><title>Visual Regression Report</title></head>"
      file.puts "<body>"
      file.puts "<h1>Visual Regression Report</h1>"
      file.puts "<ul>"

      Dir.glob(diff_dir.join("*_diff.png")).each do |diff_file|
        filename = File.basename(diff_file)
        # Extract preview and scenario names
        preview_scenario = filename.sub("_diff.png", "")
        preview, scenario = preview_scenario.split("_", 2)

        baseline_image = baseline_dir.join("#{preview}_#{scenario}.png")
        current_image = current_dir.join("#{preview}_#{scenario}.png")

        file.puts "<li>"
        file.puts "<h2>#{preview.titleize} - #{scenario.titleize}</h2>"
        file.puts "<div style='display: flex; gap: 10px;'>"
        file.puts "<div><h3>Baseline</h3><img src='#{baseline_image.relative_path_from(base_path)}' alt='Baseline'></div>"
        file.puts "<div><h3>Current</h3><img src='#{current_image.relative_path_from(base_path)}' alt='Current'></div>"
        file.puts "<div><h3>Diff</h3><img src='#{diff_file.relative_path_from(base_path)}' alt='Diff'></div>"
        file.puts "</div>"
        file.puts "</li>"
      end

      file.puts "</ul>"
      file.puts "</body>"
      file.puts "</html>"
    end

    puts "Visual regression report generated at #{report_path}"
  end
end
