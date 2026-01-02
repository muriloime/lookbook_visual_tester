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
            # Blue context for unchanged pixels to make it easier for humans
            gray_val = ChunkyPNG::Color.r(ChunkyPNG::Color.grayscale_teint(pixel1))
            # Keep intensity in R/G but push blue to make it the dominant tint
            diff_image[x, y] = ChunkyPNG::Color.rgba(gray_val, gray_val, 255, 50)
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
