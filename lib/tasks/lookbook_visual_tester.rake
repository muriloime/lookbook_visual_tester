# lib/tasks/lookbook_visual_tester.rake
require 'lookbook_visual_tester/runner'
require 'lookbook_visual_tester/report_generator'

namespace :lookbook do
  desc 'Generate screenshots for a specific preview (and run comparison)'
  task :screenshot, [:preview_name] => :environment do |_, args|
    preview_name = args[:preview_name]
    unless preview_name
      puts 'Please provide a preview name: rake lookbook:screenshot[Button]'
      exit 1
    end

    # Run the test (which generates screenshots)
    runner = LookbookVisualTester::Runner.new(pattern: preview_name)
    results = runner.run

    print_cli_summary(results)
  end

  desc 'Run visual regression tests for all previews'
  task test: :environment do
    runner = LookbookVisualTester::Runner.new
    results = runner.run

    print_cli_summary(results)

    # Generate detailed HTML report
    reporter = LookbookVisualTester::ReportGenerator.new(results)
    reporter.call

    exit 1 if results.any? { |r| r.status == :failed }
  end

  def print_cli_summary(results)
    total = results.size
    passed = results.count { |r| r.status == :passed }
    failed = results.count { |r| r.status == :failed }
    new_scenarios = results.count { |r| r.status == :new }
    errors = results.count { |r| r.status == :error }

    puts "\n"
    puts '========================================'
    puts '           Test Summary                 '
    puts '========================================'
    puts "Total Scenarios: #{total}"
    puts "Passed:          #{passed}"
    puts "Failed:          #{failed}"
    puts "New (Baselines): #{new_scenarios}" if new_scenarios > 0
    puts "Errors:          #{errors}" if errors > 0
    puts '========================================'

    if failed > 0
      puts "\nFailed Scenarios:"
      results.select { |r| r.status == :failed }.each do |r|
        puts "  [FAIL] #{r.scenario_name}"
        puts "         Mismatch: #{r.mismatch.round(2)}%"
        puts "         Diff:     #{r.diff_path}"
      end
    end

    if errors > 0
      puts "\nErrors:"
      results.select { |r| r.status == :error }.each do |r|
        puts "  [ERROR] #{r.scenario_name}"
        puts "          Message: #{r.error}"
      end
    end
    puts "\n"
  end
end

# Compatibility aliases and extra tools
namespace :lookbook_visual_tester do
  desc 'Run visual regression tests (alias for lookbook:test)'
  task run: 'lookbook:test'

  desc 'Update baseline screenshots from current_run'
  task update_baseline: 'lookbook_visual_tester:environment' do
    baseline_dir = LookbookVisualTester.config.baseline_dir
    current_dir = LookbookVisualTester.config.current_dir

    unless current_dir.exist?
      puts 'Current run directory does not exist.'
      exit 1
    end

    Dir.glob(current_dir.join('*.png')).each do |current_file|
      filename = File.basename(current_file)
      baseline_file = baseline_dir.join(filename)
      FileUtils.mkdir_p(baseline_dir)
      FileUtils.cp(current_file, baseline_file)
      puts "Updated baseline: #{filename}"
    end
  end

  desc 'Profile the visual tester'
  task profile: :environment do
    require 'ruby-prof'
    RubyProf.start
    Rake::Task['lookbook:test'].invoke
    result = RubyProf.stop
    printer = RubyProf::FlatPrinter.new(result)
    printer.print($stdout)
  end

  desc 'Get list of images for the given component'
  task :images, %i[name skip_capture] => :environment do |_, args|
    require 'lookbook_visual_tester/scenario_finder'
    scenario_run = LookbookVisualTester::ScenarioFinder.call(args[:name])

    unless scenario_run
      puts "No Lookbook previews found matching #{args[:name]}"
      exit 1
    end

    if args[:skip_capture].to_s == 'true'
      # Just print existing
    else
      # Run it first but silenty
      runner = LookbookVisualTester::Runner.new(pattern: args[:name])
      $stdout = File.new('/dev/null', 'w')
      runner.run
      $stdout = STDOUT
    end

    puts scenario_run.current_path
  end

  desc 'Run and copy to clipboard first scenario matching the given name'
  task :copy, [:name] => :environment do |_, args|
    require 'lookbook_visual_tester/scenario_finder'
    scenario_run = LookbookVisualTester::ScenarioFinder.call(args[:name])
    unless scenario_run
      puts "No Lookbook previews found matching #{args[:name]}"
      exit 1
    end

    # Use our runner to capture it (which handles clipboard if enabled)
    runner = LookbookVisualTester::Runner.new(pattern: args[:name])
    runner.run
  end
end
