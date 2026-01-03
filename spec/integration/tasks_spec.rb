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
end
