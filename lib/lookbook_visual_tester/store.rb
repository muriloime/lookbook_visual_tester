module LookbookVisualTester
  class Store
    attr_accessor :last_changed_file, :last_hash

    def initialize
      @last_hash = -1
      @last_changed_file = nil
    end

    class << self
      def data
        @data ||= new
      end

      def dataset
        yield(data)
      end
    end
  end

  def self.data
    @data ||= Store.new
  end
end
