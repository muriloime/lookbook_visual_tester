# lib/tasks/lookbook_visual_tester.rake
require 'lookbook_visual_tester/runner'
require 'lookbook_visual_tester/report_generator'
require 'lookbook_visual_tester/json_output_handler'

require 'lookbook_visual_tester/preview_checker'
require 'lookbook_visual_tester/check_reporter'

namespace :lookbook do
  desc 'Check previews for load/syntax errors'
  task check: :environment do
    puts 'Checking previews...'
    checker = LookbookVisualTester::PreviewChecker.new
    results = checker.check
    LookbookVisualTester::CheckReporter.start([results])
  end

  desc 'Deep check previews by rendering them'
  task deep_check: :environment do
    puts 'Deep checking previews (render)...'
    checker = LookbookVisualTester::PreviewChecker.new
    results = checker.deep_check
    LookbookVisualTester::CheckReporter.start([results])
    exit 1 if results.any? { |r| r.status == :failed }
  end

  desc 'Find components missing previews'
  task missing: :environment do
    puts 'Finding missing previews...'
    checker = LookbookVisualTester::PreviewChecker.new
    missing = checker.missing
    LookbookVisualTester::CheckReporter.report_missing(missing)
  end
end

namespace :lookbook do
  desc 'List all available previews'
  task :list, [:format] => :environment do |_, args|
    require 'lookbook'
    previews = Lookbook.previews.flat_map do |preview|
      group = preview.respond_to?(:scenarios) ? preview.scenarios : preview.examples
      group.map { |scenario| scenario.lookup_path }
    end.sort

    if args[:format] == 'json'
      LookbookVisualTester::JsonOutputHandler.print(previews)
    else
      puts previews
    end
  end

  desc 'Generate screenshots for a specific preview (and run comparison)'
  task :screenshot, %i[preview_name format] => :environment do |_, args|
    preview_name = args[:preview_name]
    format = args[:format]

    unless preview_name
      if format == 'json'
        LookbookVisualTester::JsonOutputHandler.print({ error: 'Please provide a preview name' })
      else
        puts 'Please provide a preview name: rake lookbook:screenshot[Button]'
      end
      exit 1
    end

    # Run the test (which generates screenshots)
    runner = LookbookVisualTester::Runner.new(pattern: preview_name)

    # Silence stdout if json format, to avoid pollution
    original_stdout = $stdout
    $stdout = File.new('/dev/null', 'w') if format == 'json'

    begin
      results = runner.run
    ensure
      $stdout = original_stdout if format == 'json'
    end

    if format == 'json'
      # Transform results to simple hash
      json_results = results.map do |r|
        {
          scenario_name: r.scenario_name,
          status: r.status,
          mismatch: r.mismatch,
          diff_path: r.diff_path,
          baseline_path: r.baseline_path,
          current_path: r.current_path,
          error: r.error
        }
      end

      # If single result, return just object, else array
      output = json_results.size == 1 ? json_results.first : json_results
      LookbookVisualTester::JsonOutputHandler.print(output)
    else
      print_cli_summary(results)
    end
  end

  desc 'Run visual regression tests for all previews'
  task :test, [:format] => :environment do |_, args|
    runner = LookbookVisualTester::Runner.new

    # Check for ENV var or arg
    json_mode = args[:format] == 'json' || ENV['JSON_OUTPUT'] == 'true'

    original_stdout = $stdout
    $stdout = File.new('/dev/null', 'w') if json_mode

    begin
      results = runner.run
    ensure
      $stdout = original_stdout if json_mode
    end

    # Save results for retry logic
    if defined?(LookbookVisualTester.config.diff_dir)
      result_file = LookbookVisualTester.config.diff_dir.join('last_run.json')
      FileUtils.mkdir_p(File.dirname(result_file))

      simplified_results = results.map do |r|
        {
          scenario_name: r.scenario_name,
          status: r.status,
          mismatch: r.mismatch,
          diff_path: r.diff_path.to_s,
          current_path: r.current_path.to_s,
          baseline_path: r.baseline_path.to_s
        }
      end
      File.write(result_file, JSON.dump(simplified_results))
    end

    if json_mode
      summary = {
        total: results.size,
        passed: results.count { |r| r.status == :passed },
        failed: results.count { |r| r.status == :failed },
        new: results.count { |r| r.status == :new },
        errors: results.count { |r| r.status == :error },
        results: results.map do |r|
          {
            name: r.scenario_name,
            status: r.status,
            mismatch: r.mismatch,
            diff_path: r.diff_path
          }
        end
      }
      LookbookVisualTester::JsonOutputHandler.print(summary)
    else
      print_cli_summary(results)

      # Generate detailed HTML report
      reporter = LookbookVisualTester::ReportGenerator.new(results)
      reporter.call

      exit 1 if results.any? { |r| r.status == :failed }
    end
  end

  desc 'Approve a specific preview change (update baseline)'
  task :approve, [:preview_name] => :environment do |_, args|
    preview_name = args[:preview_name]
    unless preview_name
      puts 'Please provide a preview name: rake lookbook:approve[Button/default]'
      exit 1
    end

    baseline_dir = LookbookVisualTester.config.baseline_dir
    current_dir = LookbookVisualTester.config.current_dir

    # Find matching files in current_dir
    candidates = Dir.glob(current_dir.join('*')).select do |f|
      File.basename(f).include?(preview_name.gsub('/', '_'))
    end

    if candidates.empty?
      puts "No current runs found matching '#{preview_name}'."
      exit 1
    end

    candidates.each do |current_file|
      filename = File.basename(current_file)
      next if filename.include?('_diff.png') # Don't copy diffs

      baseline_file = baseline_dir.join(filename)
      FileUtils.mkdir_p(baseline_dir)
      FileUtils.cp(current_file, baseline_file)
      puts "Approved: #{filename}"
    end
  end

  desc 'Re-run only failing tests from the last run'
  task :retry, [:format] => :environment do |_, args|
    result_file = LookbookVisualTester.config.diff_dir.join('last_run.json')
    unless File.exist?(result_file)
      puts "No previous run data found at #{result_file}. Run 'rake lookbook:test' first."
      exit 1
    end

    last_run = JSON.parse(File.read(result_file), symbolize_names: true)
    failures = last_run.select { |r| r[:status] == 'failed' || r[:status] == 'error' }

    if failures.empty?
      puts 'No failures found in last run.'
      exit 0
    end

    puts "Retrying #{failures.size} failure(s)..."

    failures.each do |failure|
      puts "Retrying #{failure[:scenario_name]}..."
      runner = LookbookVisualTester::Runner.new(pattern: failure[:scenario_name])
      runner.run
    end
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

  desc 'Get detailed inspection data for a preview (JSON)'
  task :inspect, [:preview_name] => :environment do |_, args|
    require 'lookbook'
    require 'lookbook_visual_tester/scenario_finder'
    require 'lookbook_visual_tester/json_output_handler'

    preview_name = args[:preview_name]
    unless preview_name
      LookbookVisualTester::JsonOutputHandler.print({ error: 'Please provide a preview name' })
      exit 1
    end

    scenario_run = LookbookVisualTester::ScenarioFinder.call(preview_name)

    unless scenario_run
      LookbookVisualTester::JsonOutputHandler.print({ error: "No preview found for #{preview_name}" })
      exit 1
    end

    scenario = scenario_run.scenario
    preview = scenario.preview
    file_path = preview.file_path

    # Try to find line number
    line_number = nil
    if File.exist?(file_path)
      File.foreach(file_path).with_index do |line, index|
        if line.match?(/^\s*def\s+#{scenario.name}\b/)
          line_number = index + 1
          break
        end
      end
    end

    # Inspect component details if available
    component_class_name = nil
    component_file_path = nil
    template_file_path = nil

    if scenario.respond_to?(:component)
      comp = scenario.component
      if comp.respond_to?(:component_class) && comp.component_class
        component_class_name = comp.component_class.name
        # Best effort to find component source
        if comp.component_class.instance_methods(false).include?(:initialize)
          component_file_path = comp.component_class.instance_method(:initialize).source_location&.first
        end
        # Fallback to const_source_location if supported (Ruby 2.7+)
        if component_file_path.nil? && Object.respond_to?(:const_source_location)
          component_file_path = Object.const_source_location(component_class_name)&.first
        end
      end

      template_file_path = comp.template_file_path if comp.respond_to?(:template_file_path)
    end

    output = {
      name: scenario.lookup_path,
      preview_class: preview.name,
      file_path: file_path,
      line_number: line_number,
      url_path: scenario.url_path,
      component_class: component_class_name,
      component_path: component_file_path,
      template_path: template_file_path
    }

    LookbookVisualTester::JsonOutputHandler.print(output)
  end

  desc 'Dump content of preview, component, and template for context'
  task :context, [:preview_name] => :environment do |_, args|
    require 'lookbook_visual_tester/json_output_handler'

    require 'lookbook'
    require 'lookbook_visual_tester/scenario_finder'

    preview_name = args[:preview_name]
    unless preview_name
      puts 'Error: Please provide a preview name'
      exit 1
    end

    scenario_run = LookbookVisualTester::ScenarioFinder.call(preview_name)

    unless scenario_run
      puts "Error: No preview found for #{preview_name}"
      exit 1
    end

    scenario = scenario_run.scenario
    preview = scenario.preview

    files_to_dump = []

    # 1. Preview File
    files_to_dump << { path: preview.file_path, label: "Preview: #{preview.name}" }

    # 2. Template File (if available)
    if scenario.respond_to?(:component)
      comp = scenario.component
      if comp.respond_to?(:template_file_path) && comp.template_file_path
        files_to_dump << { path: comp.template_file_path, label: 'Template' }
      end

      # 3. Component File (best effort)
      if comp.respond_to?(:component_class) && comp.component_class
        component_file_path = nil
        if comp.component_class.instance_methods(false).include?(:initialize)
          component_file_path = comp.component_class.instance_method(:initialize).source_location&.first
        end
        if component_file_path.nil? && Object.respond_to?(:const_source_location)
          component_file_path = Object.const_source_location(comp.component_class.name)&.first
        end

        if component_file_path
          files_to_dump << { path: component_file_path, label: "Component: #{comp.component_class.name}" }
        end
      end
    end

    files_to_dump.each do |file|
      next unless file[:path] && File.exist?(file[:path])

      puts "\n"
      puts '========================================'
      puts "#{file[:label]} (#{file[:path]})"
      puts '========================================'
      puts File.read(file[:path])
      puts '========================================'
    end
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
