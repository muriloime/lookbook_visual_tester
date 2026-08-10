# lib/lookbook_visual_tester/services/image_trimmer.rb
require 'chunky_png'

module LookbookVisualTester
  module ImageTrimmer
    DEFAULT_PADDING = 10

    # Pixels matching any of these colors are considered "empty" border and trimmed.
    BORDER_COLORS = [
      ChunkyPNG::Color::WHITE,
      ChunkyPNG::Color::TRANSPARENT
    ].freeze

    def self.call(path, padding: DEFAULT_PADDING)
      image = ChunkyPNG::Image.from_file(path)
      min_x, max_x, min_y, max_y = content_bounding_box(image)

      # No content found: keep the original image.
      return path if max_x < min_x

      cropped = image.crop(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
      cropped.border!(padding, ChunkyPNG::Color::TRANSPARENT)
      cropped.save(path)
      path
    end

    # ChunkyPNG's own #trim only strips a single uniform border color; this
    # tolerates either white or transparent border pixels, so the bounding
    # box still needs a manual scan.
    def self.content_bounding_box(image)
      min_x = image.width
      max_x = -1
      min_y = image.height
      max_y = -1

      image.height.times do |y|
        image.width.times do |x|
          next if border_pixel?(image[x, y])

          min_x = x if x < min_x
          max_x = x if x > max_x
          min_y = y if y < min_y
          max_y = y if y > max_y
        end
      end

      [min_x, max_x, min_y, max_y]
    end

    def self.border_pixel?(color)
      BORDER_COLORS.include?(color)
    end
  end
end
