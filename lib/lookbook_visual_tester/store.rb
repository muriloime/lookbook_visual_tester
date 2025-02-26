module LookbookVisualTester
  class Store
    attr_accessor :stored_hash

    HASH_KEY = 'lookbook_visual_tester:stored_hash'

    def initialize
      @stored_hash = Rails.cache.read(HASH_KEY) || {}
    end

    def [](key)
      @stored_hash[key.to_s]
    end

    def []=(key, value)
      save(key.to_s, value)
    end

    def save(key, value)
      @stored_hash[key.to_s] = value
      Rails.cache.write(HASH_KEY, @stored_hash)
    end

    # pretty inspect of the object
    def inspect
      "#<#{self.class.name}
      stored_hash: #{stored_hash}>"
    end

    class << self
      def data
        @data ||= new
        # @data ||= new
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
