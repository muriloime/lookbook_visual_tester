require 'spec_helper'
require 'lookbook_visual_tester/scenario_run'

RSpec.describe LookbookVisualTester::ScenarioRun do
  let(:preview_class_1) { double('PreviewClass', name: 'Clash::NamePreview') }
  let(:preview_1) { double('Lookbook::Preview', name: 'Clash::NamePreview', preview_class: preview_class_1) }
  let(:scenario_1) { double('Lookbook::Scenario', name: 'default', preview: preview_1) }

  let(:preview_class_2) { double('PreviewClass', name: 'ClashNamePreview') }
  let(:preview_2) { double('Lookbook::Preview', name: 'ClashNamePreview', preview_class: preview_class_2) }
  let(:scenario_2) { double('Lookbook::Scenario', name: 'default', preview: preview_2) }

  it 'generates different filenames for clashing preview names' do
    run_1 = described_class.new(scenario_1)
    run_2 = described_class.new(scenario_2)

    # Currently they are expected to clash, so this test should fail if the bug exists
    expect(run_1.filename).not_to eq(run_2.filename)
  end
end
