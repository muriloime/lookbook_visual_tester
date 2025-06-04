# lib/tasks/lookbook_visual_tester.rake
require 'fileutils'
require 'mini_magick'
require 'ruby-prof'
require 'concurrent-ruby'

require 'lookbook_visual_tester/report_generator'
require 'lookbook_visual_tester/screenshot_taker'
require 'lookbook_visual_tester/image_comparator'
require 'lookbook_visual_tester/scenario_run'

namespace :lookbook_visual_tester do
  desc 'Profile the lookbook_visual_tester:run task'
  task profile: :environment do
    RubyProf.start
    Rake::Task['lookbook_visual_tester:run'].invoke
    result = RubyProf.stop

    printer = RubyProf::FlatPrinter.new(result)
    printer.print(STDOUT)
  end

  desc "Get list of images for the given component"
  task :images, [:name] => :environment do |t, args|
    # example on how to run: `rake lookbook_visual_tester:images["Button"]`

    can_print = false # $stdout.isatty
    scenario_run = LookbookVisualTester::ScenarioFinder.call(args[:name])

    if can_print
      puts "Searching for Lookbook previews matching '#{args[:name]}'... "
      puts Lookbook.previews.map(&:name).join(', ') if Lookbook.previews.any?
    end

    unless scenario_run
      puts "No Lookbook previews found matching #{args[:name]}"
      exit
    end

    screenshot_taker = LookbookVisualTester::ScreenshotTaker.new(scenario_run:)
    screenshot_taker.call
    # images = scenario_run.images
    # if images.empty?
    #   puts "No images found for #{args[:name]}"
    #   exit 1
    # end

    # Check if output is being piped
    if $stdout.isatty # not Piped output (machine readable)
      # Terminal output (human readable)
      puts "Images for #{args[:name]}:"
      # images.each { |image| puts "- #{image}" }
    end
    puts scenario_run.current_path
  end

  desc 'Run and copy to clipboard first scenario matching the given name'
  task :copy, [:name] => :environment do |t, args|
    # example on how to run: `rake lookbook_visual_tester:copy["Button"]`

    scenario_run = LookbookVisualTester::ScenarioFinder.call(args[:name])
    unless scenario_run
      screenshot_taker = LookbookVisualTester::ScreenshotTaker.new(scenario_run:)
      puts "No Lookbook previews found matching #{args[:name]}"
      exit
    end
    screenshot_taker.call
    exit
  end

  desc 'Run visual regression tests for Lookbook previews'
  task run: :environment do
    image_comparator = LookbookVisualTester::ImageComparator.new
    report = LookbookVisualTester::ReportGenerator.new

    previews = Lookbook.previews

    if previews.empty?
      puts 'No Lookbook previews found.'
      exit
    end

    pool = Concurrent::FixedThreadPool.new(LookbookVisualTester.config.threads)
    previews.each do |preview|
      preview_name = preview.name.underscore
      puts "Processing Preview: #{preview_name}"

      preview.scenarios.each do |scenario|
        Concurrent::Promises.future_on(pool) do
          scenario_run = LookbookVisualTester::ScenarioRun.new(scenario)
          screenshot_taker = LookbookVisualTester::ScreenshotTaker.new(scenario_run:)
          screenshot_taker.capture(scenario_run.preview_url, scenario_run.current_path)
          puts "    Visiting URL: #{preview_url}"

          image_comparator.compare(scenario_run)
        end
      end
    end

    pool.shutdown
    pool.wait_for_termination
    report_path = report.generate
    puts "Visual regression report generated at #{report_path}"
  end

  desc 'Update baseline screenshots with current_run screenshots'
  task update_baseline: :environment do
    base_path = Rails.root.join('spec/visual_screenshots')
    baseline_dir = base_path.join('baseline')
    current_dir = base_path.join('current_run')

    unless current_dir.exist?
      puts 'Current run directory does not exist. Run the visual regression tests first.'
      exit
    end

    Dir.glob(current_dir.join('*.png')).each do |current_file|
      filename = File.basename(current_file)
      baseline_file = baseline_dir.join(filename)
      FileUtils.cp(current_file, baseline_file)
      puts "Baseline updated for #{filename}"
    end
  end
end
