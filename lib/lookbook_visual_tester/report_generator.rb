module LookbookVisualTester
  class ReportGenerator
    attr_reader :report_path, :baseline_dir, :current_dir, :diff_dir, :base_path

    def initialize
      @baseline_dir, @current_dir, @diff_dir, @base_path = LookbookVisualTester.config.then do |config|
        [config.baseline_dir, config.current_dir, config.diff_dir, config.base_path]
      end

      @report_path = base_path.join("report.html")
    end

    def generate
      File.open(report_path, "w") do |file|
        file.puts "<!DOCTYPE html>"
        file.puts "<html lang='en'>"
        file.puts "<head><meta charset='UTF-8'><title>Visual Regression Report</title></head>"
        file.puts "<body>"
        file.puts "<h1>Visual Regression Report</h1>"
        file.puts "<ul>"

        diff_files = Dir.glob(diff_dir.join("*_diff.png"))
        diff_files.each do |diff_file|
          filename = File.basename(diff_file)
          # Extract preview and scenario names
          preview_scenario = filename.sub("_diff.png", "")
          preview, scenario = preview_scenario.split("_", 2)

          baseline_image = baseline_dir.join("#{preview}_#{scenario}.png")
          current_image = current_dir.join("#{preview}_#{scenario}.png")

          file.puts "<li>"
          file.puts "<h2>#{preview.titleize} - #{scenario.titleize}</h2>"
          file.puts "<div style='display: flex; gap: 10px;'>"

          baseline_image_path = Pathname.new(baseline_image)
          current_image_path = Pathname.new(current_image)
          diff_file_path = Pathname.new(diff_file)

          file.puts "<div><h3>Baseline</h3><img src='#{baseline_image_path.relative_path_from(base_path)}' alt='Baseline'></div>"
          file.puts "<div><h3>Current</h3><img src='#{current_image_path.relative_path_from(base_path)}' alt='Current'></div>"
          file.puts "<div><h3>Diff</h3><img src='#{diff_file_path.relative_path_from(base_path)}' alt='Diff'></div>"
          file.puts "</div>"
          file.puts "</li>"
        end

        file.puts "<li>No differences found!</li>" if diff_files.empty?

        file.puts "</ul>"
        file.puts "</body>"
        file.puts "</html>"
      end

      @report_path
    end
  end
end
