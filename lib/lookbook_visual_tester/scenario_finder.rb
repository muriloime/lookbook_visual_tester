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
      @regex = Regexp.new(search.chars.join('.*'), Regexp::IGNORECASE)
    end

    def matched_previews
      @matched_previews ||= previews.select { |preview| regex.match?(preview.name.downcase) }
    end

    def call
      return nil if search.nil? || search == '' || previews.empty?

      previews.each do |preview|
        preview.scenarios.each do |scenario|
          return ScenarioRun.new(scenario) if scenario.name.downcase.include?(search.downcase)
        end
      end

      nil
    end
  end
end
