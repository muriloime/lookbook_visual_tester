require 'spec_helper'
require 'lookbook_visual_tester/update_previews'
require 'lookbook_visual_tester/scenario_run'
require 'lookbook_visual_tester/screenshot_taker'

RSpec.describe LookbookVisualTester::UpdatePreviews do
  let(:app) { double('app', data: double('data')) }
  let(:changes) { { modified: modified_files } }
  let(:modified_files) { [] }
  let(:service) { described_class.new(app, changes) }

  describe '#initialize' do
    it 'sets app and changes' do
      expect(service.app).to eq(app)
      expect(service.changes).to eq(modified_files)
    end
  end

  describe '#should_process?' do
    context 'when changes are empty' do
      it 'returns false' do
        expect(service.send(:should_process?)).to be false
      end
    end

    context 'when changes contain relevant files' do
      let(:modified_files) { ['some/path/button_preview.rb'] }

      it 'returns true' do
        expect(service.send(:should_process?)).to be true
      end
    end
  end

  describe '#process_change?' do
    it 'returns true for preview files' do
      expect(service.send(:process_change?, 'app/components/button_preview.rb')).to be true
    end

    it 'returns true for component files' do
      expect(service.send(:process_change?, 'app/components/button_component.rb')).to be true
      expect(service.send(:process_change?, 'app/components/button_component.html.erb')).to be true
      expect(service.send(:process_change?, 'app/components/button_component.haml')).to be true
    end

    it 'returns false for other files' do
      expect(service.send(:process_change?, 'app/models/user.rb')).to be false
    end
  end

  describe '#selected_changes' do
    let(:modified_files) do
      [
        'app/components/button_preview.rb',
        'app/models/user.rb',
        'app/components/card_component.html.erb'
      ]
    end

    it 'returns only relevant files' do
      expect(service.send(:selected_changes)).to contain_exactly(
        'app/components/button_preview.rb',
        'app/components/card_component.html.erb'
      )
    end
  end

  describe '#previews' do
    let(:modified_files) { ['app/components/button_preview.rb'] }
    let(:preview) { double('preview', file_path: 'app/components/button_preview.rb') }

    before do
      allow(Lookbook).to receive(:previews).and_return([preview])
    end

    it 'returns matching previews' do
      expect(service.send(:previews)).to contain_exactly(preview)
    end
  end

  describe '#process_changes' do
    let(:modified_files) { ['app/components/button_preview.rb'] }
    let(:scenario) { double('scenario') }
    let(:preview) { double('preview', scenarios: [scenario], file_path: 'app/components/button_preview.rb') }
    let(:scenario_run) { double('scenario_run', preview_url: 'url', current_path: 'path') }

    before do
      allow(Lookbook).to receive(:previews).and_return([preview])
      allow(LookbookVisualTester::ScenarioRun).to receive(:new).with(scenario).and_return(scenario_run)
      allow(LookbookVisualTester::ScreenshotTaker).to receive(:new).and_return(double(capture: true))
      allow(Rails.logger).to receive(:info) # Ensure logger.info is stubbed
    end

    it 'processes each preview and takes screenshots' do
      expect(LookbookVisualTester::ScreenshotTaker).to receive(:new)
      expect_any_instance_of(LookbookVisualTester::ScreenshotTaker).to receive(:capture).with('url', 'path')

      # Verify logging
      expect(Rails.logger).to receive(:info).with("LookbookVisualTester: previews #{[preview].count}")

      service.send(:process_changes)
    end
  end
end
