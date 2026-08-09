require 'spec_helper'
require 'lookbook_visual_tester/services/image_trimmer'
require 'chunky_png'
require 'fileutils'

RSpec.describe LookbookVisualTester::ImageTrimmer do
  let(:tmp_dir) { 'spec/tmp/trimmer' }
  let(:path) { "#{tmp_dir}/input.png" }

  before { FileUtils.mkdir_p(tmp_dir) }
  after  { FileUtils.rm_rf(tmp_dir) }

  def build_image(width:, height:, fill: ChunkyPNG::Color::WHITE, content_color: ChunkyPNG::Color::BLACK)
    image = ChunkyPNG::Image.new(width, height, fill)
    image[5, 5] = content_color
    image[6, 5] = content_color
    image[5, 6] = content_color
    image[6, 6] = content_color
    image
  end

  it 'trims white margins and adds padding' do
    build_image(width: 20, height: 20).save(path)

    described_class.call(path, padding: 4)

    trimmed = ChunkyPNG::Image.from_file(path)
    expect(trimmed.width).to eq(10)  # 2px blob + 4px padding each side
    expect(trimmed.height).to eq(10)
  end

  it 'preserves images that have no uniform border' do
    image = ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color.from_hex('#EFEFEF'))
    image.save(path)

    described_class.call(path, padding: 0)

    trimmed = ChunkyPNG::Image.from_file(path)
    expect(trimmed.width).to eq(10)
    expect(trimmed.height).to eq(10)
  end

  it 'raises when the file does not exist' do
    expect { described_class.call('spec/tmp/missing.png') }.to raise_error(Errno::ENOENT)
  end

  it 'returns the path' do
    build_image(width: 10, height: 10).save(path)
    expect(described_class.call(path)).to eq(path)
  end

  it 'does not shell out to ImageMagick' do
    build_image(width: 10, height: 10).save(path)
    expect(Kernel).not_to receive(:system).with(/convert/)
    expect(Kernel).not_to receive(:`).with(/convert/)
    described_class.call(path)
  end
end
