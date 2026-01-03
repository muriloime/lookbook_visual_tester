require 'spec_helper'
require 'lookbook_visual_tester/runner'

RSpec.describe LookbookVisualTester::Runner do
  let(:config) { LookbookVisualTester.config }
  let(:mock_driver) { instance_double(LookbookVisualTester::Drivers::FerrumDriver) }
  let(:preview) { double('Preview', name: 'Forms/Input', lookup_path: 'forms/input') }
  let(:scenario) { double('Scenario', name: 'Default', preview: preview) }

  before do
    allow(preview).to receive(:respond_to?).with(:scenarios).and_return(true)
    allow(preview).to receive(:scenarios).and_return([scenario])
    allow(Lookbook).to receive(:previews).and_return([preview])
    allow(LookbookVisualTester::Drivers::FerrumDriver).to receive(:new).and_return(mock_driver)

    # Mock Driver methods
    allow(mock_driver).to receive(:resize_window)
    allow(mock_driver).to receive(:visit)
    allow(mock_driver).to receive(:save_screenshot)
    allow(mock_driver).to receive(:cleanup)

    # Mock ImageComparator
    allow(LookbookVisualTester::ImageComparator).to receive(:new).and_return(double(call: { mismatch: 0.0 }))

    # Mock FileUtils
    allow(FileUtils).to receive(:mkdir_p)

    # Mock VariantResolver
    allow(LookbookVisualTester::VariantResolver).to receive(:new).and_call_original
  end

  describe '#run' do
    context 'without variants (default)' do
      it 'visits the preview url' do
        runner = described_class.new
        runner.run

        expect(mock_driver).to have_received(:visit).with(include('forms/input/Default'))
      end

      it 'resizes window to default' do
        runner = described_class.new
        runner.run
        expect(mock_driver).to have_received(:resize_window).with(1280, 800)
      end
    end

    context 'with variants provided via ENV' do
      before do
        stub_const('ENV', ENV.to_hash.merge('VARIANTS' => '[{"theme":"dark"}, {"width":"iPhone 12"}]'))

        # Mocking lookbook config for resolver
        allow(Lookbook).to receive(:config).and_return(
          double(preview_display_options: { width: [['iPhone 12', '390px']] })
        )
      end

      it 'runs scenarios for each variant' do
        runner = described_class.new
        runner.run

        # Should confirm visit called twice, once with dark theme, once with iphone width
        expect(mock_driver).to have_received(:visit).twice
      end

      it 'resizes window logic' do
        runner = described_class.new
        runner.run

        # Default run + Dark run should use default size? OR resolver handles it?
        # 1st variant (theme: dark) -> default size
        # 2nd variant (width: iphone 12) -> size 390

        # NOTE: VariantResolver logic needs to be fully loaded or mocked.
        # Checking resize calls:
        expect(mock_driver).to have_received(:resize_window).with(1280, 800) # Dark theme (no width)
        expect(mock_driver).to have_received(:resize_window).with(390, 800) # iPhone width (height defaults if not specified?) - Actually resolver doesn't support height yet unless window_size added.
        # Wait, plan said 'parse to int'. Need to update expectation based on impl.
      end
    end
  end
end
