require 'spec_helper'
require 'lookbook_visual_tester/update_previews'
require 'lookbook_visual_tester/scenario_run'

RSpec.describe LookbookVisualTester::UpdatePreviews do
  let(:app) { double('app', data: double('data')) }
  let(:changes) { { modified: modified_files } }
  let(:modified_files) { [] }
  let(:service) { described_class.new(changes) }

  describe '#initialize' do
    it 'sets changes' do
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

  describe '#selected_previews' do
    let(:modified_files) { ['app/components/button_preview.rb'] }
    let(:preview) { double('preview', file_path: 'app/components/button_preview.rb', name: 'Button') }

    before do
      allow(Lookbook).to receive(:previews).and_return([preview])
    end

    it 'returns matching previews' do
      expect(service.send(:selected_previews)).to contain_exactly(preview)
    end
  end

  describe '#process_changes' do
    let(:modified_files) { ['app/components/button_preview.rb'] }
    let(:scenario) { double('scenario') }
    let(:preview) { double('preview', scenarios: [scenario], file_path: 'app/components/button_preview.rb', name: 'Button') }
    let(:runner) { double('Runner') }

    before do
      allow(preview).to receive(:respond_to?).with(:scenarios).and_return(true)
      allow(Lookbook).to receive(:previews).and_return([preview])
      allow(LookbookVisualTester::Runner).to receive(:new).with(pattern: 'Button').and_return(runner)
      allow(runner).to receive(:run)
      allow(Rails.logger).to receive(:info)
    end

    it 'runs the Ferrum Runner for each changed preview' do
      expect(LookbookVisualTester::Runner).to receive(:new).with(pattern: 'Button')
      expect(runner).to receive(:run)

      service.send(:process_changes)
    end
  end
end
