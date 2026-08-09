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

      # No content found: keep the original image.
      return path if max_x < min_x

      content_width = max_x - min_x + 1
      content_height = max_y - min_y + 1
      new_width = content_width + (padding * 2)
      new_height = content_height + (padding * 2)

      trimmed = ChunkyPNG::Image.new(new_width, new_height, ChunkyPNG::Color::TRANSPARENT)

      image.height.times do |y|
        image.width.times do |x|
          next if x < min_x || x > max_x || y < min_y || y > max_y

          trimmed[x - min_x + padding, y - min_y + padding] = image[x, y]
        end
      end

      trimmed.save(path)
      path
    end

    def self.border_pixel?(color)
      BORDER_COLORS.include?(color)
    end
  end
end
