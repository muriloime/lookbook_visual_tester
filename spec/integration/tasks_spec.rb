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
end
