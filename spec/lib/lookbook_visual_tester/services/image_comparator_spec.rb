require 'spec_helper'
require 'lookbook_visual_tester/services/image_comparator'
require 'chunky_png'
require 'fileutils'

RSpec.describe LookbookVisualTester::ImageComparator do
  let(:tmp_dir) { "spec/tmp/images" }
  let(:baseline_path) { "#{tmp_dir}/baseline.png" }
  let(:current_path) { "#{tmp_dir}/current.png" }
  let(:diff_path) { "#{tmp_dir}/diff.png" }

  before do
    FileUtils.mkdir_p(tmp_dir)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  def create_image(path, color, width: 10, height: 10)
    image = ChunkyPNG::Image.new(width, height, color)
    image.save(path)
  end

  describe "#call" do
    context "when baseline does not exist" do
      it "returns error" do
        comparator = described_class.new(baseline_path, current_path, diff_path)
        result = comparator.call
        expect(result[:error]).to eq("Baseline not found")
      end
    end

    context "when images are identical" do
      before do
        create_image(baseline_path, ChunkyPNG::Color::WHITE)
        create_image(current_path, ChunkyPNG::Color::WHITE)
      end

      it "returns 0 mismatch and no diff path" do
        comparator = described_class.new(baseline_path, current_path, diff_path)
        result = comparator.call
        expect(result[:mismatch]).to eq(0.0)
        expect(result[:diff_path]).to be_nil
        expect(result[:error]).to be_nil
      end
    end

    context "when images have different dimensions" do
      before do
        create_image(baseline_path, ChunkyPNG::Color::WHITE, width: 10, height: 10)
        create_image(current_path, ChunkyPNG::Color::WHITE, width: 20, height: 20)
      end

      it "returns 100% mismatch and error" do
        comparator = described_class.new(baseline_path, current_path, diff_path)
        result = comparator.call
        expect(result[:mismatch]).to eq(100.0)
        expect(result[:error]).to include("Dimensions mismatch")
      end
    end

    context "when images differ" do
      before do
        # Baseline is all white
        create_image(baseline_path, ChunkyPNG::Color::WHITE, width: 10, height: 10)

        # Current has one black pixel
        image = ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color::WHITE)
        image[0, 0] = ChunkyPNG::Color::BLACK
        image.save(current_path)
      end

      it "returns mismatch percentage and saves diff" do
        comparator = described_class.new(baseline_path, current_path, diff_path)
        result = comparator.call

        # 1 pixel out of 100 is different -> 1% mismatch
        expect(result[:mismatch]).to eq(1.0)
        expect(result[:diff_path]).to eq(diff_path)
        expect(File.exist?(diff_path)).to be true
      end
    end
  end
end
