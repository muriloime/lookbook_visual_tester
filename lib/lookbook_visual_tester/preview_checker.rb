require 'concurrent'
require 'benchmark'

module LookbookVisualTester
  class PreviewChecker
    CheckResult = Struct.new(:preview_name, :example_name, :status, :error, :backtrace, :duration,
                             keyword_init: true)
    MissingResult = Struct.new(:component_path, keyword_init: true)

    def initialize(config = LookbookVisualTester.config)
      @config = config
    end

    def check
      run_checks(:basic_check)
    end

    def deep_check
      run_setup
      run_checks(:deep_render_check)
    end

    def missing
      components_dir = Rails.root.join(@config.components_folder)
      previews_dir = preview_paths.first

      components = Dir.glob(File.join(components_dir, '**', '*_component.rb'))

      missing = []
      components.each do |component_path|
        next if component_path.end_with?('application_component.rb')
        next if component_path.include?('/concerns/')

        relative_path = Pathname.new(component_path).relative_path_from(components_dir).to_s
        preview_relative_path = relative_path.sub('_component.rb', '_component_preview.rb')
        preview_path = File.join(previews_dir, preview_relative_path)

        missing << MissingResult.new(component_path: relative_path) unless File.exist?(preview_path)
      end
      missing
    end

    private

    def preview_paths
      if defined?(Rails) && Rails.application.config.view_component.preview_paths.any?
        Rails.application.config.view_component.preview_paths.map { |p| Pathname.new(p) }
      else
        [Rails.root.join('test/components/previews')]
      end
    end

    def run_setup
      @config.preview_checker_setup&.call
    end

    def run_checks(check_method)
      previews = Lookbook.previews
      work_items = previews.flat_map do |preview|
        preview.scenarios.map { |example| { preview: preview, example: example } }
      end

      if @config.threads > 1
        pool = Concurrent::FixedThreadPool.new(@config.threads)
        promises = work_items.map do |item|
          Concurrent::Promises.future_on(pool) do
            measure_and_send(item[:preview], item[:example], check_method)
          end
        end
        results = Concurrent::Promises.zip(*promises).value
        pool.shutdown
        pool.wait_for_termination
        results
      else
        work_items.map { |item| measure_and_send(item[:preview], item[:example], check_method) }
      end
    end

    def measure_and_send(preview, example, method_name)
      result = nil
      time = Benchmark.realtime { result = send(method_name, preview, example) }
      result.duration = time
      result
    end

    def basic_check(preview, example)
      preview_class = preview.preview_class
      example_name = example.name

      begin
        preview_instance = preview_class.new
        return CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed) unless preview_instance.respond_to?(example_name)

        preview_instance.public_send(example_name)
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed)
      rescue StandardError => e
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :failed,
                        error: e.message, backtrace: e.backtrace)
      end
    end

    def deep_render_check(preview, example)
      preview_class = preview.preview_class
      example_name = example.name

      begin
        if preview_class.respond_to?(:preview_example)
          result = preview_class.preview_example(example_name)
        else
          preview_instance = preview_class.new
          return CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed) unless preview_instance.respond_to?(example_name)
          result = preview_instance.public_send(example_name)
        end

        result = result[:component] if result.is_a?(Hash) && result.key?(:component)

        if result.respond_to?(:render_in)
          output = result.render_in(build_view_context)
          if output.is_a?(String) && output.include?('ActionView::Template::Error')
            return CheckResult.new(preview_name: preview.name, example_name: example_name,
                                   status: :failed, error: 'ActionView::Template::Error found in rendered output',
                                   backtrace: [])
          end
        elsif result.is_a?(String)
          if result.include?('ActionView::Template::Error')
            return CheckResult.new(preview_name: preview.name, example_name: example_name,
                                   status: :failed, error: 'ActionView::Template::Error found in rendered output',
                                   backtrace: [])
          end
        elsif result.nil?
          verify_implicit_template!(preview_class, example_name)
        end

        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed)
      rescue StandardError => e
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :failed,
                        error: e.message, backtrace: e.backtrace)
      end
    end

    def build_view_context
      controller = if defined?(ApplicationController)
                     ApplicationController.new
                   else
                     ActionController::Base.new
                   end
      controller.request = ActionDispatch::TestRequest.create
      controller.view_context
    end

    def verify_implicit_template!(preview_class, example_name)
      method = preview_class.instance_method(example_name)
      source_file = method&.source_location&.first
      return if source_file.nil?

      dir = File.dirname(source_file)
      filename = File.basename(source_file, '.rb')
      template_dir = File.join(dir, filename)

      extensions = ['.html.erb', '.html.haml', '.html.slim']
      path = File.join(template_dir, example_name)

      return if extensions.any? { |ext| File.exist?("#{path}#{ext}") }

      raise ViewComponent::MissingPreviewTemplateError.new(
        "Preview #{example_name} returned nil and no template found at #{path}.* (checked erb, haml, slim)"
      ) if defined?(ViewComponent::MissingPreviewTemplateError)

      raise "Preview returned nil and no template found at #{path}.*"
    end
  end
end
