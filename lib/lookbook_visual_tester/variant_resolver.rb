module LookbookVisualTester
  class VariantResolver
    attr_reader :input_variant

    def initialize(input_variant)
      @input_variant = input_variant || {}
    end

    def resolve
      resolved = {}
      @input_variant.each do |key, label|
        resolved[key.to_sym] = resolve_value(key, label)
      end
      resolved
    end

    def slug
      return '' if @input_variant.empty?

      @input_variant.sort_by { |k, _v| k.to_s }.map do |key, label|
        "#{key}-#{sanitize(label)}"
      end.join('_')
    end

    def width_in_pixels
      resolved_width = resolve[:width]
      return nil unless resolved_width

      if resolved_width.to_s.end_with?('px')
        resolved_width.to_i
      else
        nil # Ignore percentages or other units for resizing
      end
    end

    private

    def resolve_value(key, label)
      options = Lookbook.config.preview_display_options[key.to_sym]
      return label unless options

      # Options can be an array of strings or array of [label, value] arrays
      found = options.find do |option|
        if option.is_a?(Array)
          option[0] == label
        else
          option == label
        end
      end

      if found
        found.is_a?(Array) ? found[1] : found
      else
        label
      end
    end

    def sanitize(value)
      value.to_s.gsub(/[^a-zA-Z0-9]/, '_').squeeze('_').gsub(/^_|_$/, '')
    end
  end
end
