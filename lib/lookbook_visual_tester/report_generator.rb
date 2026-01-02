require 'erb'
require 'fileutils'

module LookbookVisualTester
  class ReportGenerator
    TEMPLATE_PATH = File.expand_path("../templates/report.html.erb", __FILE__)
    OUTPUT_PATH = "coverage/visual_report.html"

    def initialize(results)
      @results = results
      @stats = {
        total: results.size,
        failed: results.count { |r| r.status == :failed },
        new: results.count { |r| r.status == :new },
        passed: results.count { |r| r.status == :passed }
      }
    end

    def call
      template = File.read(TEMPLATE_PATH)
      renderer = ERB.new(template)
      html = renderer.result(binding)

      FileUtils.mkdir_p("coverage")
      File.write(OUTPUT_PATH, html)
      puts "📊 Report generated at: #{OUTPUT_PATH}"
    end

    # Helper to generate the terminal command for the user
    def approve_command(result)
      "cp \"#{result.current_path}\" \"#{result.baseline_path}\""
    end
  end
end
