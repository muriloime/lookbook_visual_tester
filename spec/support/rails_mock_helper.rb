module RailsMockHelper
  class MockLogger
    def info(*); end
    def error(*); end
  end

  class MockRails
    def self.logger
      @logger ||= MockLogger.new
    end
  end

  def self.mock_rails_logger
    Object.const_set(:Rails, MockRails) unless defined?(Rails)
    MockRails.logger
  end
end
