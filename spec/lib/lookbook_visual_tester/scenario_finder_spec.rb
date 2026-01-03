require 'spec_helper'

RSpec.describe LookbookVisualTester::ScenarioFinder do
  let(:previews) { [] }
  let(:search) { 'button' }
  let(:finder) { described_class.new(search, previews: previews) }

  describe '#call' do
    context 'when search is blank' do
      let(:search) { '' }
      it 'returns nil' do
        expect(finder.call).to be_nil
      end
    end

    context 'when previews are empty' do
      let(:previews) { [] }
      it 'returns nil' do
        expect(finder.call).to be_nil
      end
    end

    context 'with matching scenarios' do
      let(:scenario) { double('Scenario', name: 'Primary Button', preview: preview) }

      let(:preview) { double('Preview', name: 'ButtonPreview', scenarios: [scenario]) }
      let(:previews) { [preview] }

      xit 'returns a ScenarioRun for the matching scenario' do
        result = finder.call
        expect(result).to be_a(LookbookVisualTester::ScenarioRun)
        expect(result.scenario).to eq(scenario)
        expect(result.scenario.preview).to eq(preview)
      end
    end

    context 'with no matching scenarios' do
      let(:scenario) { double('Scenario', name: 'Something Else') }
      let(:preview) { double('Preview', name: 'OtherPreview', scenarios: [scenario]) }
      let(:previews) { [preview] }

      it 'returns nil' do
        expect(finder.call).to be_nil
      end
    end
  end

  describe '#matched_previews' do
    let(:preview1) { double('Preview', name: 'ButtonPreview') }
    let(:preview2) { double('Preview', name: 'CardPreview') }
    let(:previews) { [preview1, preview2] }

    it 'returns previews matching the regex pattern' do
      expect(finder.matched_previews).to include(preview1)
      expect(finder.matched_previews).not_to include(preview2)
    end
  end
end
