# frozen_string_literal: true

require_relative 'lib/lookbook_visual_tester/version'

Gem::Specification.new do |spec|
  spec.name = 'lookbook_visual_tester'
  spec.version = LookbookVisualTester::VERSION
  spec.authors = ['Murilo Vasconcelos']
  spec.email = ['muriloime@gmail.com']

  spec.summary       = 'Visual regression testing for Lookbook previews in Rails applications.'
  spec.description   = 'A Rails gem that captures screenshots of Lookbook component previews, compares them against baseline images, and highlights visual differences to assist in safe refactoring.'
  spec.homepage      = 'https://github.com/muriloime/lookbook_visual_tester'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.0.0'

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem

  spec.add_dependency 'benchmark'
  spec.add_dependency 'chunky_png'
  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'cuprite'
  spec.add_dependency 'ferrum'
  spec.add_dependency 'lookbook'
  spec.add_dependency 'rails'
  spec.add_dependency 'rainbow'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'ruby-prof'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
