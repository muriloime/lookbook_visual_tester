require 'spec_helper'
require 'lookbook_visual_tester/check_reporter'
require 'lookbook_visual_tester/preview_checker'

RSpec.describe LookbookVisualTester::CheckReporter do
  let(:check_result) do
    LookbookVisualTester::PreviewChecker::CheckResult.new(
      preview_name: 'TestPreview',
      example_name: 'default',
      status: :passed,
      duration: 0.1
    )
  end
  let(:results) { [check_result] }
  let(:reporter) { described_class.new(results) }

  # Thor::Group.start methods usually instantiate and run.
  # But we can also instantiate and call `invoke_all`.

  describe '#report' do
    it 'outputs to terminal' do
      expect { described_class.start([results]) }.to output(/Check Results/).to_stdout
    end

    it 'generates HTML report' do
      # Mock the template method or check file creation
      # Since we are using Thor::Actions, it's hard to mock internal `template`.
      # Let's run it and check file.
      allow(FileUtils).to receive(:mkdir_p)

      # We allow the template to run. It will verify the template file exists.
      # We can mock File.write if we want to avoid filesystem writes,
      # but Thor writes to file.

      # Let's use a temporary directory or just let it write and clean up.
      # Since we are in a spec, let's just let it write.

      described_class.start([results])

      output_path = 'coverage/preview_check_report.html'
      expect(File.exist?(output_path)).to be true
      expect(File.read(output_path)).to include('TestPreview')
    end
  end
end
