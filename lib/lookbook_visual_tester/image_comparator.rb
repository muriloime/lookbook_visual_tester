require "lookbook_visual_tester/configuration"

module LookbookVisualTester
  class ImageComparator
    attr_reader :baseline_dir, :current_dir, :diff_dir

    def initialize
      @baseline_dir = LookbookVisualTester.config.baseline_dir
      @current_dir = LookbookVisualTester.config.current_dir
      @diff_dir = LookbookVisualTester.config.diff_dir
    end

    def compare(scenario_run)
      filename = scenario_run.filename

      current_path = current_dir.join(filename)
      baseline_path = baseline_dir.join(filename)
      diff_path = diff_dir.join(scenario_run.diff_filename)

      if baseline_path.exist?
        baseline_image = MiniMagick::Image.open(baseline_path)
        current_image  = MiniMagick::Image.open(current_path)

        unless baseline_image.dimensions == current_image.dimensions
          puts "    Image dimensions do not match. Skipping comparison."
          return
        end

        begin
          compare_command = "compare -metric AE \"#{baseline_path}\" \"#{current_path}\" \"#{diff_path}\" 2>&1"
          result = `#{compare_command}`
          distortion = result.strip.to_i

          if distortion > 0
            puts "    Differences found! Diff image saved to #{diff_path}"
          else
            puts "    No differences detected."
            File.delete(diff_path) if diff_path.exist?
          end
        rescue StandardError => e
          puts "    Error comparing images: #{e.message}"
        end
      else
        FileUtils.cp(current_path, baseline_path)
        puts "    Baseline image created at #{baseline_path}"
      end
    end
  end
end
