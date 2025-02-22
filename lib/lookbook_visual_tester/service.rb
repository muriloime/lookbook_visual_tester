module LookbookVisualTester
  class Service
    def self.call(*)
      new(*).call
    end

    def call
      raise NotImplementedError, 'You must implement the call method'
    end
  end
end
