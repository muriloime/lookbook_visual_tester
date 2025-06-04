require 'lookbook_visual_tester/service'
require 'lookbook_visual_tester/scenario_run'

module LookbookVisualTester
  class ScenarioFinder < Service
    attr_reader :fuzze, :search, :previews

    def initialize(search, fuzzy: true, previews: Lookbook.previews)
      @search = search
      @fuzzy = fuzzy
      @previews = previews
    end

    def regex
      @regex = Regexp.new(clean_search.chars.join('.*'), Regexp::IGNORECASE)
    end

    def matched_previews
      @matched_previews ||= previews.select { |preview| regex.match?(preview.name.downcase) }
    end

    def clean_search
      @clean_search ||= search.downcase.gsub(/[^a-z0-9\s]/, '').strip
    end

    def call
      return nil if search.nil? || search == '' || previews.empty?

      previews.each do |preview|
        preview.scenarios.each do |scenario|
          name = "#{preview.name} #{scenario.name}".downcase
          return ScenarioRun.new(scenario) if regex.match?(name.downcase) #name.downcase.include?(clean_search)
        end
      end

      nil
    end
  end
end
