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
      # Ensure custom setup is run before deep checks
      run_setup
      run_checks(:deep_render_check)
    end

    def missing
      components_dir = Rails.root.join(@config.components_folder)
      # Assuming standard structure: test/components/previews for previews
      # But Lookbook can be configured differently. We should use Lookbook's config if possible to know where previews are.
      # For now, let's stick to the user's script logic which assumes standard paths or iterate through loaded components.

      # Better approach: Iterate through all known components and check if they have a preview.
      # However, "all known components" might be hard to get if they aren't loaded.
      # Let's use the file system approach as in the user script.

      components = Dir.glob(File.join(components_dir, '**', '*_component.rb'))
      previews_dir = Rails.root.join('test/components/previews') # Default, maybe make configurable?

      # Trying to find where previews are located from Rails config if possible
      if defined?(Rails) && Rails.application.config.view_component.preview_paths.any?
        # Use simple heuristic: first path
        previews_dir = Pathname.new(Rails.application.config.view_component.preview_paths.first)
      end

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

    def run_checks(check_method)
      previews = Lookbook.previews
      results = []

      # We want to flatten the work items: (PreviewClass, example_name)
      work_items = []
      previews.each do |preview|
        # preview is a Lookbook::Preview object which wraps the class
        # But for checking we might want the class directly or iterate examples
        examples = preview.examples
        examples.each do |example|
          work_items << { preview: preview, example: example }
        end
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
      else
        results = work_items.map do |item|
          measure_and_send(item[:preview], item[:example], check_method)
        end
      end

      results
    end

    def measure_and_send(preview, example, method_name)
      result = nil
      time = Benchmark.realtime do
        result = send(method_name, preview, example)
      end
      result.duration = time
      result
    end

    def basic_check(preview, example)
      # user script logic:
      # preview_instance = preview_class.new
      # component = preview_instance.public_send(preview_example)
      # if component.respond_to?(:render_in) ...

      # Lookbook::Preview wrapper might help, but let's go to the class
      preview_class = preview.preview_class
      example_name = example.name

      begin
        preview_instance = preview_class.new
        preview_instance.public_send(example_name)

        # We don't render, just verify we can call it.
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
        preview_instance = preview_class.new
        result = preview_instance.public_send(example_name)

        if result.respond_to?(:render_in)
          # Mock current_user/pundit if needed on the component itself if possible
          # But mainly we render it with a view context
          view_context = setup_view_context

          # Inject mocks into result if it supports it or reliance on global view_context
          # The user script defines singleton methods on the result.
          if @mocks
            @mocks.each do |key, value|
              if result.respond_to?(key) || !result.respond_to?(key) # Force define
                result.define_singleton_method(key) { value }
              end
            end
          end

          result.render_in(view_context)
        elsif result.is_a?(String)
          # Rendered string, good.
        end

        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :passed)
      rescue StandardError => e
        CheckResult.new(preview_name: preview.name, example_name: example_name, status: :failed,
                        error: e.message, backtrace: e.backtrace)
      end
    end

    def run_setup
      if @config.preview_checker_setup
        @config.preview_checker_setup.call
      else
        default_setup
      end
    end

    def default_setup
      # Logic from the user's script
      # We need to set up a controller and view context globally or for use in checks

      # This part is tricky because we need to make these available to the `deep_render_check` method.
      # We can store the view_context in an instance variable or re-create it.

      # Let's perform the class-level mocks here (User, etc.)

      # Mock User
      unless defined?(User)
        # Defining a dummy user if not exists is risky if the app doesn't have User.
        # But the script assumes User exists or creates a mock.
        # Let's create a OpenStruct-like mock for typical Devise/Pundit usage.
      end

      # The script logic:
      # controller = ApplicationController.new ...
      # We will do this in `setup_view_context` called per check or once?
      # `ApplicationController` might not be thread safe if we modify it?
      # Actually we create a new controller instance.

      # Define @mocks to be injected
      @mocks = {}
      @mocks[:current_user] = build_mock_user
      @mocks[:pundit_user] = @mocks[:current_user]
    end

    def build_mock_user
      # Try to load a real user or build a struct
      if defined?(User) && User.respond_to?(:first) && User.first
        User.first
      else
        # Fallback mock
        u = Object.new
        u.define_singleton_method(:email) { 'test@example.com' }
        u.define_singleton_method(:id) { 1 }
        # Add other common methods as needed or let them fail/mock dynamic
        u
      end
    end

    def setup_view_context
      # We need a controller to get a view context
      controller = if defined?(ApplicationController)
                     ApplicationController.new
                   else
                     ActionController::Base.new
                   end

      controller.request = ActionDispatch::TestRequest.create
      if controller.request.env
        controller.request.env['rack.session'] = {}
        controller.request.env['rack.session.options'] = { id: SecureRandom.uuid }
      end

      # Devise mapping
      if defined?(Devise)
        controller.request.env['devise.mapping'] = Devise.mappings[:user] if Devise.mappings[:user]

        # Mock warden
        warden = Object.new
        warden.define_singleton_method(:authenticate!) { |*| true }
        warden.define_singleton_method(:authenticate) { |*| true }
        warden.define_singleton_method(:user) { |*| @mocks[:current_user] }
        controller.request.env['warden'] = warden
      end

      view_context = controller.view_context

      # Add helper methods to view_context
      # We can use `class_eval` on the singleton class of the view context
      vc_singleton = view_context.singleton_class

      if @mocks
        @mocks.each do |key, value|
          vc_singleton.send(:define_method, key) { value }
        end
      end

      # Common auth helpers
      vc_singleton.send(:define_method, :signed_in?) { true }

      # Pundit policy mock
      vc_singleton.send(:define_method, :policy) do |_record|
        Struct.new(:show?, :index?, :create?, :update?, :destroy?, :edit?, :new?, :manage?).new(
          true, true, true, true, true, true, true, true
        )
      end

      view_context
    end
  end
end
