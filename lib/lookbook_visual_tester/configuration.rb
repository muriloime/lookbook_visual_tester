module LookbookVisualTester
  class Configuration
    attr_accessor :base_path, :lookbook_host,
                  :baseline_dir, :current_dir, :diff_dir, :history_dir,
                  :history_keep_last_n, :threads, :copy_to_clipboard,
                  :components_folder,
                  :automatic_run,
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
      @threads = DEFAULT_THREADS
      @history_keep_last_n = 5
      @copy_to_clipboard = true
      @components_folder = 'app/components'
      @automatic_run = ENV.fetch('LOOKBOOK_AUTOMATIC_RUN', false)
      @logger = if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
                  Rails.logger
                else
                  require 'logger'
                  Logger.new($stdout).tap { |l| l.level = Logger::INFO }
                end

      @lookbook_host = ENV.fetch('LOOKBOOK_HOST', 'http://localhost:5000')
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
