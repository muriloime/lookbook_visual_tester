# lib/lookbook_visual_tester/server_test_runner.rb
require 'net/http'
require 'uri'
require 'timeout'
require 'tempfile'

module LookbookVisualTester
  class ServerTestRunner
    DEFAULT_TEST_TASK = 'lookbook:test'
    DEFAULT_TIMEOUT = 60
    POLL_INTERVAL = 0.25

    def self.call(config: LookbookVisualTester.config, timeout: DEFAULT_TIMEOUT, test_task: DEFAULT_TEST_TASK, log_path: nil)
      new(config: config, timeout: timeout, test_task: test_task, log_path: log_path).call
    end

    def initialize(config: LookbookVisualTester.config, timeout: DEFAULT_TIMEOUT, test_task: DEFAULT_TEST_TASK, log_path: nil)
      @config = config
      @timeout = timeout
      @test_task = test_task
      @log_path = log_path
      @pid = nil
      @log_file = nil
    end

    def call
      validate_host!
      @pid = spawn_server

      begin
        self.class.wait_for_server(@config.lookbook_host, timeout: @timeout)
        puts "[LookbookVisualTester] Server ready at #{@config.lookbook_host}. Running #{@test_task}..."

        task = Rake::Task[@test_task]
        task.reenable
        task.invoke
      ensure
        stop_server
      end
    end

    def self.wait_for_server(host, timeout: DEFAULT_TIMEOUT)
      uri = URI.parse(host)
      raise Error, "Invalid lookbook_host: #{host}" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      Timeout.timeout(timeout) do
        loop do
          begin
            response = Net::HTTP.get_response(uri)
            return true if response.code.to_i < 500
          rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::OpenTimeout, Net::ReadTimeout
            # server not ready yet
          end
          sleep POLL_INTERVAL
        end
      end
    rescue Timeout::Error
      raise Error, "Lookbook server at #{host} did not start within #{timeout}s"
    end

    private

    def validate_host!
      host = @config.lookbook_host
      raise Error, 'lookbook_host must be configured' if host.nil? || host.empty?

      uri = URI.parse(host)
      raise Error, "Invalid lookbook_host: #{host}" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise Error, "lookbook_host must include a port: #{host}" unless uri.port
    end

    def spawn_server
      port = URI.parse(@config.lookbook_host).port
      env = {
        'PORT' => port.to_s,
        'RAILS_ENV' => ENV.fetch('RAILS_ENV', 'development')
      }
      command = ['bundle', 'exec', 'rails', 'server', '-p', port.to_s]

      @log_file = @log_path ? File.open(@log_path, 'w') : Tempfile.create('lookbook_server')
      Process.spawn(env, *command, out: @log_file, err: @log_file, pgroup: true)
    end

    def stop_server
      return unless @pid

      begin
        Process.kill('-TERM', @pid) # negative pid signals the whole process group
      rescue Errno::ESRCH
        # already gone
      end

      begin
        Process.waitpid(@pid)
      rescue Errno::ECHILD
        # already reaped
      end
    ensure
      @log_file&.close
    end
  end
end
