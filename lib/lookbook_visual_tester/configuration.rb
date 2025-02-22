module LookbookVisualTester
  class Configuration
    attr_accessor :base_path, :baseline_dir, :current_dir, :diff_dir, :threads, :host

    DEFAULT_THREADS = 4

    def initialize
      @base_path = Rails.root.join('spec/visual_screenshots')
      @baseline_dir = @base_path.join('baseline')
      @current_dir = @base_path.join('current_run')
      @diff_dir = @base_path.join('diff')
      @threads = DEFAULT_THREADS

      @host = ENV['LOOKBOOK_HOST'] || 'https://localhost:5000'

      [baseline_dir, current_dir, diff_dir].each do |dir|
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      end
    end
  end

  def self.config
    @config ||= Configuration.new
  end
end
