require_relative '../driver'
require 'ferrum'

module LookbookVisualTester
  module Drivers
    class FerrumDriver < Driver
      def initialize(config)
        super
        @browser = Ferrum::Browser.new(
          headless: true,
          window_size: [1280, 800], # Default, can be resized
          timeout: 10 # Configurable?
        )
      end

      def visit(url)
        @browser.go_to(url)
        prepare_page
      end

      def resize_window(width, height)
        @browser.resize(width: width, height: height)
      end

      def inject_style(css)
        # Ferrum allows adding style tags via JS
        script = <<~JS
          const style = document.createElement('style');
          style.innerHTML = `#{css}`;
          document.head.appendChild(style);
        JS
        @browser.execute(script)
      end

      def run_script(script)
        @browser.execute(script)
      end

      def mask_elements(selectors)
        return if selectors.empty?

        selectors.each do |selector|
          script = <<~JS
            document.querySelectorAll('#{selector}').forEach(el => {
              el.style.visibility = 'hidden';
            });
          JS
          @browser.execute(script)
        end
      end

      def wait_for_assets
        wait_for_network_idle
        wait_for_fonts
        wait_for_custom_selectors
        # Explicit wait if configured, for robustness against "blank screenshot" issues
        sleep(config.wait_time) if config.wait_time.positive?
      end

      def wait_for_fonts
        @browser.execute('return document.fonts.ready')
      end

      def wait_for_network_idle
        # Ferrum has built-in network idle waiting.
        # We rely on default settings or explicit sleep for extra safety.
        @browser.network.wait_for_idle
      rescue Ferrum::TimeoutError
        # Log warning but proceed - sometimes long polling or other scripts keep net active
        config.logger.warn 'LookbookVisualTester: Network idle timeout. Proceeding with screenshot.'
      end

      def save_screenshot(path)
        @browser.screenshot(path: path, full: true)
        # NOTE: full: true captures the whole page.
        # If we capture viewport only, we should remove full: true.
        # Usually for visual testing full page is better unless specifically testing viewport.
      end

      def cleanup
        @browser.quit
      end

      private

      def prepare_page
        disable_animations
        mask_elements(config.mask_selectors || [])
        wait_for_assets
      end

      def disable_animations
        css = '* { transition: none !important; animation: none !important; caret-color: transparent !important; }'
        inject_style(css)
      end

      def wait_for_custom_selectors
        # If we have specific selectors to wait for e.g. document.fonts.status check loop
        start = Time.now
        until @browser.execute("return document.fonts.status === 'loaded'")
          break if Time.now - start > 5

          sleep 0.1
        end

        # Also check for images loading attributes if needed
        # "check that no images have loading attributes active"
        # Often checking complete property is enough
        until @browser.execute('return Array.from(document.images).every(i => i.complete)')
          break if Time.now - start > 5

          sleep 0.1
        end
      end
    end
  end
end
