require 'spec_helper'
require 'lookbook_visual_tester/runner'

RSpec.describe LookbookVisualTester::Runner do
  let(:config) { LookbookVisualTester.config }
  let(:mock_driver) { instance_double(LookbookVisualTester::Drivers::FerrumDriver) }
  let(:preview) { double("Preview", name: "Forms/Input", lookup_path: "forms/input") }
  let(:scenario) { double("Scenario", name: "Default", preview: preview) }

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
  end

  describe "#run" do
    it "initializes the driver" do
      described_class.new
      expect(LookbookVisualTester::Drivers::FerrumDriver).to have_received(:new).with(config)
    end

    it "visits the preview url" do
      runner = described_class.new
      runner.run

      # URL construction: forms/input/Default -> verify visit called
      expect(mock_driver).to have_received(:visit).with(include("forms/input/Default"))
    end

    it "takes a screenshot" do
      runner = described_class.new
      runner.run

      expect(mock_driver).to have_received(:save_screenshot).with(include("forms_input_default.png"))
    end

    it "compares images" do
      comparator_double = double(call: { mismatch: 0.0 })
      allow(LookbookVisualTester::ImageComparator).to receive(:new).and_return(comparator_double)

      runner = described_class.new
      runner.run

      expect(LookbookVisualTester::ImageComparator).to have_received(:new)
      expect(comparator_double).to have_received(:call)
    end

    it "cleans up the driver" do
      runner = described_class.new
      runner.run

      expect(mock_driver).to have_received(:cleanup)
    end
  end
end
