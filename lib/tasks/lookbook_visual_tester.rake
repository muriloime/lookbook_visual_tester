# lib/tasks/lookbook_visual_tester.rake

require "capybara"
require "capybara/cuprite"
require "fileutils"
require "mini_magick"
require "ruby-prof"

require "lookbook_visual_tester/report_generator"
require "lookbook_visual_tester/screenshot_taker"
require "lookbook_visual_tester/image_comparator"
require "lookbook_visual_tester/scenario_run"

namespace :lookbook_visual_tester do
  desc "Profile the lookbook_visual_tester:run task"
  task profile: :environment do
    RubyProf.start
    Rake::Task["lookbook_visual_tester:run"].invoke
    result = RubyProf.stop

    printer = RubyProf::FlatPrinter.new(result)
    printer.print(STDOUT)
  end

  desc "Run visual regression tests for Lookbook previews"
  task run: :environment do
    screenshot_taker = LookbookVisualTester::ScreenshotTaker.new
    image_comparator = LookbookVisualTester::ImageComparator.new
    report = LookbookVisualTester::ReportGenerator.new

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
        scenario_run = LookbookVisualTester::ScenarioRun.new(scenario)

        # Generate preview URL
        # binding.pry
        preview_url = Lookbook::Engine.routes.url_helpers.lookbook_preview_url(
          # preview: preview.name,
          path: preview.lookup_path + "/" + scenario.name,
          # scenario: scenario.name,
          host: ENV["LOOKBOOK_HOST"] || "https://localhost:5000"
        )

        screenshot_taker.capture(preview_url, scenario_run.current_path)
        puts "    Visiting URL: #{preview_url}"

        image_comparator.compare(scenario_run)
      end
    end

    # Generate HTML report
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
