require 'spec_helper'
require 'lookbook_visual_tester/configuration'

RSpec.describe LookbookVisualTester::Configuration do
  subject(:config) { described_class.new }

  it 'defaults copy_to_clipboard to false' do
    with_env_stub { expect(config.copy_to_clipboard).to be(false) }
  end

  it 'defaults driver_adapter to ferrum' do
    expect(config.driver_adapter).to eq(:ferrum)
  end

  it 'defaults automatic_run to false when env is unset' do
    with_env_stub('LOOKBOOK_AUTOMATIC_RUN' => 'false') do
      expect(described_class.new.automatic_run).to be(false)
    end
  end

  it 'parses automatic_run as true when LOOKBOOK_AUTOMATIC_RUN=true' do
    with_env_stub('LOOKBOOK_AUTOMATIC_RUN' => 'true') do
      expect(described_class.new.automatic_run).to be(true)
    end
  end

  it 'accepts a preview_checker_setup callable' do
    setup = -> { :ok }
    config.preview_checker_setup = setup
    expect(config.preview_checker_setup).to eq(setup)
  end

  it 'defaults preview_checker_setup to nil' do
    expect(config.preview_checker_setup).to be_nil
  end

  it 'keeps legacy wait_time default' do
    expect(config.wait_time).to eq(0.5)
  end

  # Stubbing ENV.fetch is fragile because Configuration calls several keys.
  # Use a real ENV round-trip via a helper that restores the original values.
  def with_env_stub(overrides = {})
    original = overrides.keys.to_h { |k| [k, ENV[k]] }
    overrides.each { |k, v| ENV[k] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
