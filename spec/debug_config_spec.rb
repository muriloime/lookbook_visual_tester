require 'spec_helper'

RSpec.describe 'Debugging Config' do
  it 'prints config' do
    puts "DEBUG: ViewComponent Preview Controller: #{begin
      Rails.application.config.view_component.preview_controller
    rescue StandardError
      'nil'
    end}"
    puts "DEBUG: Lookbook Preview Controller: #{begin
      Rails.application.config.lookbook.preview_controller
    rescue StandardError
      'nil'
    end}"

    if defined?(Lookbook::PreviewController)
      puts "DEBUG: Lookbook::PreviewController ancestors: #{Lookbook::PreviewController.ancestors}"
    end
  end
end
