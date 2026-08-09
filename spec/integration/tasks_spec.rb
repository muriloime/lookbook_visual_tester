require 'spec_helper'
require 'rake'

RSpec.describe 'Rake tasks' do
  before(:all) do
    Rails.application.load_tasks
  end

  it 'has lookbook:test task' do
    expect(Rake::Task.task_defined?('lookbook:test')).to be true
  end

  it 'has lookbook:screenshot task' do
    expect(Rake::Task.task_defined?('lookbook:screenshot')).to be true
  end

  it 'has lookbook:approve task' do
    expect(Rake::Task.task_defined?('lookbook:approve')).to be true
  end

  it 'registers lookbook:server_and_test' do
    expect(Rake::Task.task_defined?('lookbook:server_and_test')).to be true
  end

  it 'does not reassign $stdout during lookbook:test in json mode' do
    original = $stdout
    runner_double = double('Runner', run: [])
    allow(LookbookVisualTester::Runner).to receive(:new).and_return(runner_double)

    Rake::Task['lookbook:test'].reenable
    Rake::Task['lookbook:test'].invoke('json')

    expect($stdout).to equal(original)
  end

  describe 'lookbook:approve' do
    it 'approves the correct baseline file for a namespaced preview and ignores decoys' do
      current_dir = LookbookVisualTester.config.current_dir
      baseline_dir = LookbookVisualTester.config.baseline_dir
      FileUtils.mkdir_p(current_dir.join('theme-dark'))
      FileUtils.mkdir_p(baseline_dir.join('theme-dark'))

      file = current_dir.join('theme-dark/ui_button_default.png')
      File.write(file, 'fake-png-data')

      decoy = current_dir.join('theme-dark/ui_button_defaultmobile.png')
      File.write(decoy, 'should-not-be-approved')

      begin
        Rake::Task['lookbook:approve'].reenable
        Rake::Task['lookbook:approve'].invoke('ui/button/default')

        expect(File.exist?(baseline_dir.join('theme-dark/ui_button_default.png'))).to be(true)
        expect(File.exist?(baseline_dir.join('theme-dark/ui_button_defaultmobile.png'))).to be(false)
      ensure
        FileUtils.rm_rf(current_dir.join('theme-dark'))
        FileUtils.rm_f(baseline_dir.join('theme-dark/ui_button_default.png'))
        FileUtils.rm_f(baseline_dir.join('theme-dark/ui_button_defaultmobile.png'))
      end
    end
  end
end
