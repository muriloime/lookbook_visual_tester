module LookbookVisualTester
  class Configuration
    attr_reader :base_path
    attr_accessor :lookbook_host,
                  :baseline_dir, :current_dir, :diff_dir, :history_dir,
                  :history_keep_last_n, :threads, :copy_to_clipboard,
                  :components_folder,
                  :automatic_run,
                  :mask_selectors, :driver_adapter,
                  :logger

    DEFAULT_THREADS = 4

    def initialize
      @base_path = if defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?
                     Pathname.new(Dir.pwd).join('spec/visual_screenshots')
                   elsif defined?(Rails) && Rails.respond_to?(:root) && Rails.root
                     Rails.root.join('spec/visual_screenshots')
                   else
                     # Fallback for non-Rails environments
                     Pathname.new(Dir.pwd).join('spec/visual_screenshots')
                   end
      @baseline_dir = @base_path.join('baseline')
      @current_dir = @base_path.join('current_run')
      @diff_dir = @base_path.join('diff')
      @history_dir = @base_path.join('history')
      @threads = ENV.fetch('LOOKBOOK_THREADS', DEFAULT_THREADS).to_i
      @history_keep_last_n = 5
      @copy_to_clipboard = true
      @components_folder = 'app/components'
      @automatic_run = ENV.fetch('LOOKBOOK_AUTOMATIC_RUN', false)
      @mask_selectors = []
      @driver_adapter = :ferrum
      @logger = if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
                  Rails.logger
                else
                  require 'logger'
                  Logger.new($stdout).tap { |l| l.level = Logger::INFO }
                end

      @lookbook_host = ENV.fetch('LOOKBOOK_HOST', 'http://localhost:5000')
    end

    def base_path=(value)
      @base_path = Pathname.new(value)
      @baseline_dir = @base_path.join('baseline')
      @current_dir = @base_path.join('current_run')
      @diff_dir = @base_path.join('diff')
      @history_dir = @base_path.join('history')
    end

    class << self
      def config
        @config ||= new
      end

      def configure
        yield(config)
      end
    end
  end

  def self.config
    @config ||= Configuration.new
  end
end
