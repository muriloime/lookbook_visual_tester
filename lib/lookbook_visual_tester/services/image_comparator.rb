require 'chunky_png'
require 'fileutils'

module LookbookVisualTester
  class ImageComparator
    attr_reader :baseline_path, :current_path, :diff_path

    # Neon Red for differences
    DIFF_COLOR = ChunkyPNG::Color.from_hex('#FF073A')

    def initialize(baseline_path, current_path, diff_path)
      @baseline_path = baseline_path
      @current_path = current_path
      @diff_path = diff_path
    end

    def call
      unless File.exist?(baseline_path)
        return { diff_path: nil, mismatch: 0.0, error: "Baseline not found" }
      end

      baseline = ChunkyPNG::Image.from_file(baseline_path)
      current = ChunkyPNG::Image.from_file(current_path)

      if baseline.dimension != current.dimension
        return {
          diff_path: nil,
          mismatch: 100.0,
          error: "Dimensions mismatch: #{baseline.width}x#{baseline.height} vs #{current.width}x#{current.height}"
        }
      end

      diff_pixels_count = 0
      diff_image = ChunkyPNG::Image.new(baseline.width, baseline.height, ChunkyPNG::Color::WHITE)

      baseline.height.times do |y|
        baseline.width.times do |x|
          pixel1 = baseline[x, y]
          pixel2 = current[x, y]

          if pixel1 != pixel2
            diff_image[x, y] = DIFF_COLOR
            diff_pixels_count += 1
          else
            # Grayscale context for unchanged pixels
            gray = ChunkyPNG::Color.grayscale_teint(pixel1)
            # Fade it (high alpha means more opaque, low alpha means more transparent in ChunkyPNG?)
            # ChunkyPNG::Color.fade(color, alpha) -> alpha 0-255 where 255 is opaque.
            # We want it somewhat visible.
            diff_image[x, y] = ChunkyPNG::Color.fade(gray, 50)
          end
        end
      end

      mismatch_percentage = (diff_pixels_count.to_f / baseline.pixels.size) * 100.0

      if diff_pixels_count > 0
        FileUtils.mkdir_p(File.dirname(diff_path))
        diff_image.save(diff_path)
        { diff_path: diff_path, mismatch: mismatch_percentage, error: nil }
      else
        { diff_path: nil, mismatch: 0.0, error: nil }
      end
    rescue StandardError => e
      { diff_path: nil, mismatch: 0.0, error: e.message }
    end
  end
end
