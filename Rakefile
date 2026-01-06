# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
# Load gem tasks
Dir.glob('lib/tasks/*.rake').each { |r| import r }

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

task default: %i[spec rubocop]

namespace :release do
  desc 'Release with OTP (MFA) support'
  task :otp do
    require 'io/console'
    print 'Enter OTP code: '
    otp = $stdin.noecho(&:gets).strip
    puts "\n"
    ENV['GEM_HOST_OTP_CODE'] = otp
    Rake::Task['release'].invoke
  end
end
