require 'spec_helper'
require 'lookbook_visual_tester/variant_resolver'

RSpec.describe LookbookVisualTester::VariantResolver do
  let(:lookbook_config) do
    {
      theme: %w[default dark],
      width: [
        ['Default', '100%'],
        ['iPhone 12', '390px'],
        ['Pixel 7', '412px']
      ]
    }
  end

  before do
    allow(Lookbook).to receive(:config).and_return(
      double(preview_display_options: lookbook_config)
    )
  end

  describe '#resolve' do
    context 'with valid input' do
      it 'resolves width label to pixel value' do
        variant = { 'width' => 'iPhone 12' }
        resolved = described_class.new(variant).resolve
        expect(resolved[:width]).to eq('390px')
      end

      it 'keeps theme as is' do
        variant = { 'theme' => 'dark' }
        resolved = described_class.new(variant).resolve
        expect(resolved[:theme]).to eq('dark')
      end

      it 'resolves multiple options' do
        variant = { 'width' => 'iPhone 12', 'theme' => 'dark' }
        resolved = described_class.new(variant).resolve
        expect(resolved[:width]).to eq('390px')
        expect(resolved[:theme]).to eq('dark')
      end
    end

    context 'with unknown options' do
      it 'passes unknown values through' do
        variant = { 'width' => 'Unknown Device' }
        resolved = described_class.new(variant).resolve
        expect(resolved[:width]).to eq('Unknown Device')
      end
    end
  end

  describe '#slug' do
    it 'generates a slug from sorted options' do
      variant = { 'width' => 'iPhone 12', 'theme' => 'dark' }
      slug = described_class.new(variant).slug
      expect(slug).to eq('theme-dark_width-iPhone_12')
    end

    it 'handles empty options' do
      variant = {}
      slug = described_class.new(variant).slug
      expect(slug).to eq('')
    end

    it 'sanitizes values' do
      variant = { 'width' => 'Pixel 7' }
      slug = described_class.new(variant).slug
      expect(slug).to eq('width-Pixel_7')
    end
  end

  describe '#width_in_pixels' do
    it 'returns nil if no width' do
      resolver = described_class.new({ 'theme' => 'dark' })
      expect(resolver.width_in_pixels).to be_nil
    end

    it 'parses pixel values' do
      resolver = described_class.new({ 'width' => 'iPhone 12' })
      expect(resolver.width_in_pixels).to eq(390)
    end

    it 'returns nil for percentage widths' do
      resolver = described_class.new({ 'width' => 'Default' })
      expect(resolver.width_in_pixels).to be_nil
    end
  end
end
