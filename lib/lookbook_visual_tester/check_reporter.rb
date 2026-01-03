require 'rainbow'
require 'thor/group'

module LookbookVisualTester
  class CheckReporter < Thor::Group
    include Thor::Actions

    argument :results

    def self.source_root
      File.dirname(__FILE__)
    end

    def report
      @errors = results.select { |r| r.status == :failed }
      @success_count = results.count { |r| r.status == :passed }
      @total_duration = results.sum { |r| r.duration.to_f }

      report_terminal
      report_html
    end

    def self.report_missing(missing)
      if missing.any?
        puts Rainbow("\nFound #{missing.size} components missing previews:").yellow
        missing.sort_by { |m| m.component_path }.each do |m|
          puts "  - #{m.component_path}"
        end
        puts "\nTotal: #{missing.size} missing previews."
      else
        puts Rainbow('All components have previews!').green
      end
    end

    private

    attr_reader :errors, :success_count, :total_duration

    def report_terminal
      puts "\n--- Check Results ---"

      results.each do |result|
        if result.status == :passed
          print Rainbow('.').green
        else
          print Rainbow('F').red
        end
      end
      puts "\n"

      if errors.any?
        puts Rainbow("\n#{errors.size} errors found:").red
        errors.each do |err|
          puts "\n--------------------------------------------------"
          puts "Preview: #{err.preview_name}##{err.example_name}"
          puts "Error: #{err.error}"
          puts "Time: #{err.duration.to_f.round(4)}s"
          puts "Backtrace: #{err.backtrace&.first(3)&.join("\n  ")}"
        end
      else
        puts Rainbow("\nAll #{results.size} previews passed!").green
      end

      puts "\nTotal time: #{total_duration.round(2)}s"

      report_slowest_previews
    end

    def report_slowest_previews
      puts "\n--- Top 5 Slowest Previews ---"
      slowest = results.sort_by { |r| -r.duration.to_f }.first(5)
      slowest.each do |res|
        puts "#{Rainbow("#{res.duration.to_f.round(4)}s").yellow} - #{res.preview_name}##{res.example_name}"
      end
    end

    def report_html
      template 'templates/preview_check_report.html.tt', 'coverage/preview_check_report.html'
    end
  end
end
