# lib/lookbook_visual_tester/browser_discovery.rb
require 'rbconfig'

module LookbookVisualTester
  # Finds a usable Chrome/Chromium binary, preferring standard absolute paths
  # over PATH-resolved lookups. PATH lookup can resolve to wrapper scripts
  # (e.g. a shell wrapper that injects GPU/Wayland flags) that break headless
  # Chrome with errors like "Multiple targets are not supported in headless mode".
  module BrowserDiscovery
    LINUX_CANDIDATES = %w[
      /usr/bin/google-chrome-stable
      /usr/bin/google-chrome
      /usr/bin/chromium
      /usr/bin/chromium-browser
      /opt/google/chrome/google-chrome
    ].freeze

    MAC_CANDIDATES = %w[
      /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
      /Applications/Chromium.app/Contents/MacOS/Chromium
    ].freeze

    def self.find_binary
      candidates = case RbConfig::CONFIG['host_os']
                   when /darwin/ then MAC_CANDIDATES
                   else LINUX_CANDIDATES
                   end
      candidates.find { |path| File.executable?(path) }
    end
  end
end
