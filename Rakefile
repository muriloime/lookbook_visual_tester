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

  desc 'Build the gem and push it to RubyGems (reads .env / RUBYGEMS_API_KEY)'
  task :gem do
    require 'fileutils'
    load_dotenv

    api_key = ENV['RUBYGEMS_API_KEY'] || ENV['GEM_HOST_API_KEY']
    unless api_key
      abort <<~MSG
        Missing RubyGems API key.
        Set RUBYGEMS_API_KEY (or GEM_HOST_API_KEY) in your environment or .env:
          https://rubygems.org/profile/api_keys  (enable MFA scopes as needed)
        Then run: rake release:gem
      MSG
    end

    write_credentials(api_key)
    Rake::Task['build'].invoke

    gem_path = Dir.glob('pkg/*.gem').max_by { |f| File.mtime(f) }
    push_cmd = ['gem', 'push', gem_path]
    push_cmd += ['--otp', ENV['GEM_HOST_OTP_CODE']] if ENV['GEM_HOST_OTP_CODE']
    sh(*push_cmd)
  end

  def load_dotenv
    path = File.expand_path('.env', Dir.pwd)
    return unless File.file?(path)
    File.readlines(path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      key, val = line.split('=', 2)
      next unless key && val
      ENV[key] = val.delete_suffix("\n").strip unless ENV.key?(key)
    end
  end

  def write_credentials(api_key)
    creds_path = File.expand_path('~/.gem/credentials')
    creds = if File.file?(creds_path)
              File.read(creds_path)
            else
              ''
            end
    updated = if creds =~ /^:rubygems_api_key: /
               creds.gsub(/^:rubygems_api_key: .*/, ":rubygems_api_key: #{api_key}")
             else
               creds + ":rubygems_api_key: #{api_key}\n"
             end
    FileUtils.mkdir_p(File.dirname(creds_path))
    File.write(creds_path, updated)
    FileUtils.chmod(0o600, creds_path)
  end
end
