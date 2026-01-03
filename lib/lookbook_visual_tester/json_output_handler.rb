require 'json'

module LookbookVisualTester
  class JsonOutputHandler
    def self.print(data)
      puts JSON.pretty_generate(data)
    end
  end
end
