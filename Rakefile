# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'minitest/test_task'

Minitest::TestTask.create

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[test rubocop]

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
