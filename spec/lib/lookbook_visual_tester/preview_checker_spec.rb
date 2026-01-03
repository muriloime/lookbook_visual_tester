require 'spec_helper'
require 'lookbook_visual_tester/preview_checker'

RSpec.describe LookbookVisualTester::PreviewChecker do
  let(:config) { LookbookVisualTester::Configuration.new }
  let(:checker) { described_class.new(config) }

  describe '#check' do
    let(:preview_class) { Class.new }
    let(:preview_obj) { double('Lookbook::Preview', name: 'TestPreview', examples: [double(name: 'default')], preview_class: preview_class) }

    before do
      allow(Lookbook).to receive(:previews).and_return([preview_obj])
    end

    it 'passes when preview method exists' do
      allow_any_instance_of(preview_class).to receive(:default)
      results = checker.check
      expect(results.first.status).to eq(:passed)
    end

    it 'fails when preview method raises error' do
      allow_any_instance_of(preview_class).to receive(:default).and_raise(StandardError, 'Expected failure')
      results = checker.check
      expect(results.first.status).to eq(:failed)
      expect(results.first.error).to eq('Expected failure')
    end
  end

  describe '#deep_check' do
    let(:preview_class) { Class.new }
    let(:preview_obj) { double('Lookbook::Preview', name: 'TestPreview', examples: [double(name: 'default')], preview_class: preview_class) }
    let(:component) { double('Component') }

    before do
      allow(Lookbook).to receive(:previews).and_return([preview_obj])
    end

    it 'passes when render_in works' do
      allow_any_instance_of(preview_class).to receive(:default).and_return(component)
      allow(component).to receive(:respond_to?).and_return(true)
      allow(component).to receive(:render_in)

      # Mock the view context setup which is complex
      allow(checker).to receive(:setup_view_context).and_return(double('ViewContext'))

      results = checker.deep_check
      expect(results.first.status).to eq(:passed)
    end
  end
end
