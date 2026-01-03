require 'spec_helper'
require 'lookbook_visual_tester/scenario_run'
require 'lookbook_visual_tester/variant_resolver'

RSpec.describe LookbookVisualTester::ScenarioRun do
  let(:scenario) { double('Scenario', name: 'Default', preview: preview) }
  let(:preview) { double('Preview', name: 'Forms/Input', lookup_path: 'forms/input') }

  before do
    allow(LookbookVisualTester.config).to receive(:baseline_dir).and_return(Pathname.new('/tmp/baseline'))
    allow(LookbookVisualTester.config).to receive(:current_dir).and_return(Pathname.new('/tmp/current'))
    allow(LookbookVisualTester.config).to receive(:diff_dir).and_return(Pathname.new('/tmp/diff'))
    allow(LookbookVisualTester.config).to receive(:lookbook_host).and_return('http://localhost:5000')

    # Mock routing
    url_helpers = double
    allow(url_helpers).to receive(:lookbook_preview_url) { |args|
      "http://localhost:5000/lookbook/preview/#{args[:path]}?#{args.except(:path, :host).to_query}"
    }
    allow(Lookbook::Engine).to receive(:routes).and_return(double(url_helpers: url_helpers))
  end

  describe '#initialize' do
    it 'accepts variant slug and params' do
      run = described_class.new(scenario, variant_slug: 'mobile', display_params: { theme: 'dark' })
      expect(run).to be_a(described_class)
    end
  end

  describe '#paths' do
    context 'without variant' do
      subject { described_class.new(scenario) }

      it 'uses root directories' do
        expect(subject.baseline_path.to_s).to eq('/tmp/baseline/forms_input_default.png')
        expect(subject.current_path.to_s).to eq('/tmp/current/forms_input_default.png')
      end
    end

    context 'with variant' do
      subject { described_class.new(scenario, variant_slug: 'theme-dark') }

      it 'uses variant subdirectory' do
        expect(subject.baseline_path.to_s).to eq('/tmp/baseline/theme-dark/forms_input_default.png')
        expect(subject.current_path.to_s).to eq('/tmp/current/theme-dark/forms_input_default.png')
      end
    end
  end

  describe '#preview_url' do
    context 'without variant' do
      subject { described_class.new(scenario) }

      it 'returns standard url' do
        expect(subject.preview_url).to include('http://localhost:5000/lookbook/preview/forms/input/Default')
      end
    end

    context 'with variant' do
      subject { described_class.new(scenario, variant_slug: 'mobile', display_params: { theme: 'dark', width: '375px' }) }

      it 'includes display params in url' do
        url = subject.preview_url
        expect(url).to include('_display%5Btheme%5D=dark') # _display[theme]=dark
        expect(url).to include('_display%5Bwidth%5D=375px')
      end
    end
  end
end
