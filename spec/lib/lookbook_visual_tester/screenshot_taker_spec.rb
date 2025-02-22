require 'spec_helper'
require 'lookbook_visual_tester/screenshot_taker'
require 'tempfile'

RSpec.describe LookbookVisualTester::ScreenshotTaker do
  let(:preview_url) { 'http://localhost:3000/preview' }
  let(:path) { '/tmp/test_screenshot.png' }
  let(:logger) { instance_double(Logger, info: true, puts: true) }
  let(:session) { instance_double(Capybara::Session) }
  let(:session_manager) { instance_double(LookbookVisualTester::SessionManager, session:) }
  let(:service) { described_class.new(preview_url, path, logger:) }

  before do
    allow(LookbookVisualTester::SessionManager).to receive(:instance).and_return(session_manager)
    allow(session).to receive(:visit)
    allow(session).to receive(:save_screenshot)
    allow(FileUtils).to receive(:mkdir_p)
    allow(service).to receive(:system).and_return(true)
  end

  describe '#initialize' do
    it 'sets the preview_url and path' do
      expect(service.preview_url).to eq(preview_url)
      expect(service.path).to eq(path)
    end

    it 'defaults crop to true' do
      expect(service.crop).to be true
    end

    it 'allows crop to be set to false' do
      service = described_class.new(preview_url, path, crop: false)
      expect(service.crop).to be false
    end

    it 'defaults path to clipboard' do
      service = described_class.new(preview_url)
      expect(service.path).to eq('clipboard')
    end
  end

  describe '#session' do
    it 'returns the session from SessionManager' do
      expect(service.session).to eq(session)
    end
  end

  describe '#call' do
    it 'creates directory for screenshot' do
      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(path))
      service.call
    end

    it 'visits the preview URL' do
      expect(session).to receive(:visit).with(preview_url)
      service.call
    end

    it 'saves screenshot to file when path is provided' do
      expect(session).to receive(:save_screenshot).with(path)
      service.call
    end

    it 'crops the screenshot when crop is true' do
      expect(service).to receive(:system).with("convert #{path} -trim -bordercolor white -border 10x10 #{path}")
      service.call
    end

    context 'when path is clipboard' do
      let(:service) { described_class.new(preview_url, described_class::CLIPBOARD, logger:) }

      it 'uses tempfile and copies to clipboard' do
        expect(service).to receive(:print_and_save_to_clipboard)
        service.call
      end
    end

    context 'when an error occurs' do
      before do
        allow(session).to receive(:visit).and_raise(StandardError.new('Test error'))
      end

      it 'logs the error and reraises it' do
        expect(logger).to receive(:info).with("Error capturing screenshot for #{preview_url}: Test error")
        expect { service.call }.to raise_error(StandardError, 'Test error')
      end
    end
  end

  describe '#save_to_clipboard' do
    it 'copies image to clipboard using xclip' do
      expect(service).to receive(:system).with("xclip -selection clipboard -t image/png -i #{path}")
      service.save_to_clipboard
    end
  end
end
