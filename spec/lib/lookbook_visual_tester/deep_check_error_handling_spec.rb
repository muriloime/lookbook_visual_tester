require 'spec_helper'
require 'lookbook_visual_tester/preview_checker'

RSpec.describe LookbookVisualTester::PreviewChecker do
  describe '#deep_check' do
    it 'detects ActionView::Template::Error in ErrorWrapperComponent' do
      # Ensure Lookbook knows about the preview
      # This relies on Lookbook loading previews from the dummy app

      checker = described_class.new
      results = checker.deep_check

      error_result = results.find { |r| r.preview_name == 'error_wrapper' && r.example_name == 'default' }

      expect(error_result).not_to be_nil
      expect(error_result.status).to eq(:failed)
      expect(error_result.error).to include('uninitialized constant')
    end
  end
end
