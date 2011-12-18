module Draper
  class DecoratedEnumerableProxy
    include Enumerable
    
    attr_reader :wrapped_collection, :klass, :options
    
    def initialize(collection, klass, options = {})
      @wrapped_collection, @klass, @options = collection, klass, options
    end
    
    def to_json(options = {})
      @wrapped_collection.to_json(options)
    end
    
    def to_xml(options = {})
      @wrapped_collection.to_xml(options)
    end
    
    def each(&block)
      @wrapped_collection.each { |member| block.call(member.decorate(@options)) }
    end

    def to_ary
      @wrapped_collection.map { |member| member.decorate(@options) }
    end

    def method_missing (method, *args, &block)
      @wrapped_collection.send(method, *args, &block)
    end

    def respond_to?(method)
      super || @wrapped_collection.respond_to?(method)
    end

    def ==(other)
      @wrapped_collection == other
    end

    def [](index)
      @klass.new(@wrapped_collection[index], @options)
    end

    def to_s
      "#<DecoratedEnumerableProxy of #{@klass} for #{@wrapped_collection.inspect}>"
    end
  end
end
