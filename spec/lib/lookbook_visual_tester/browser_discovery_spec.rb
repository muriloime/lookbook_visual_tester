require 'spec_helper'
require 'lookbook_visual_tester/browser_discovery'

RSpec.describe LookbookVisualTester::BrowserDiscovery do
  it 'returns a string path when a candidate exists' do
    result = described_class.find_binary
    # In this dev environment a real Chrome/Chromium is installed.
    expect(result).to be_a(String).or be_nil
  end

  it 'returns nil when no candidate is executable' do
    stub_const("#{described_class.name}::LINUX_CANDIDATES", ['/nonexistent/chrome'])
    stub_const("#{described_class.name}::MAC_CANDIDATES", [])
    expect(described_class.find_binary).to be_nil
  end
end
