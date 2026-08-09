require 'spec_helper'
require 'lookbook_visual_tester/preview_checker'

RSpec.describe LookbookVisualTester::PreviewChecker do
  let(:config) { LookbookVisualTester::Configuration.new }
  let(:checker) { described_class.new(config) }

  describe '#deep_check' do
    let(:preview_class) { Class.new }
    let(:example) { double(name: 'default') }
    let(:preview_obj) { double('Lookbook::Preview', name: 'TestPreview', scenarios: [example], preview_class: preview_class) }
    let(:component) { double('Component') }

    before do
      allow(Lookbook).to receive(:previews).and_return([preview_obj])
    end

    it 'fails when render_in returns an error page string containing ActionView::Template::Error' do
      allow_any_instance_of(preview_class).to receive(:default).and_return(component)
      allow(component).to receive(:respond_to?).and_return(true)

      allow(checker).to receive(:build_view_context).and_return(double('ViewContext'))

      # Simulate render_in returning an error page string instead of raising
      error_page_html = '<html><body><h1>ActionView::Template::Error</h1><p>Something went wrong</p></body></html>'
      allow(component).to receive(:render_in).and_return(error_page_html)

      results = checker.deep_check

      # This expectation captures the BUG: currently it passes (returns :passed), but we want it to fail
      # So we expect it to be :failed, and if the test fails (i.e. it is :passed), we reproduced the bug.
      expect(results.first.status).to eq(:failed)
      expect(results.first.error).to include('ActionView::Template::Error')
    end
  end
end
