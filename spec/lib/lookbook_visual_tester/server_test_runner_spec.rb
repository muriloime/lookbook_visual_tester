require 'spec_helper'
require 'lookbook_visual_tester/server_test_runner'

RSpec.describe LookbookVisualTester::ServerTestRunner do
  let(:config) { LookbookVisualTester::Configuration.new }

  before do
    allow(LookbookVisualTester).to receive(:config).and_return(config)
    config.lookbook_host = 'http://localhost:5000'
  end

  it 'requires a lookbook_host' do
    config.lookbook_host = nil
    expect { described_class.call }.to raise_error(LookbookVisualTester::Error, /lookbook_host/)
  end

  it 'raises on an invalid lookbook_host URL' do
    config.lookbook_host = 'not-a-url'
    expect { described_class.call }.to raise_error(LookbookVisualTester::Error, /lookbook_host/)
  end

  describe '.wait_for_server' do
    it 'returns true when the server responds < 500' do
      allow(Net::HTTP).to receive(:get_response).and_return(double(code: '200'))
      expect(described_class.wait_for_server(config.lookbook_host, timeout: 1)).to be(true)
    end

    it 'raises when the server never responds' do
      allow(Net::HTTP).to receive(:get_response).and_raise(Errno::ECONNREFUSED)
      expect { described_class.wait_for_server(config.lookbook_host, timeout: 0.1) }.to raise_error(LookbookVisualTester::Error, /did not start/)
    end
  end
end
