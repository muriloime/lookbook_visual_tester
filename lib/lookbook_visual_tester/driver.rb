module LookbookVisualTester
  class Driver
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def visit(url)
      raise NotImplementedError
    end

    def resize_window(width, height)
      raise NotImplementedError
    end

    def inject_style(css)
      raise NotImplementedError
    end

    def run_script(script)
      raise NotImplementedError
    end

    def mask_elements(selectors)
      raise NotImplementedError
    end

    # Smart wait implementation
    def wait_for_assets
      wait_for_fonts
      wait_for_network_idle
    end

    def wait_for_fonts
      raise NotImplementedError
    end

    def wait_for_network_idle
      raise NotImplementedError
    end

    def save_screenshot(path)
      raise NotImplementedError
    end

    def cleanup
      raise NotImplementedError
    end
  end
end
