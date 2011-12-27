module Draper::ModelSupport
  extend ActiveSupport::Concern

  def decorator(options = {})
    cache_key = options.flatten.join.parameterize
    cache_key = cache_key.blank? ? "default" : cache_key
    @decorator ||= {}
    @decorator[cache_key] ||= begin
      decorator_version = options[:version] || :default
      decorator_class = self.class.recursively_find_decorator(decorator_version)
      decorator_class.new(self, options) if decorator_class
    end
    block_given? ? yield(@decorator[cache_key]) : @decorator[cache_key]
  end
  
  def model
    self
  end
  
  alias :decorate :decorator

  module ClassMethods
    def decorate(options = {})
      cache_key = options.flatten.join.parameterize
      cache_key = cache_key.blank? ? "default" : cache_key
      @decorator ||= {}
      @decorator[cache_key] = begin
        decorator_version = options[:version] || :default
        decorator_class = self.recursively_find_decorator(decorator_version)
        decorator_class.decorate(self.scoped, options) if decorator_class
      end
      block_given? ? yield(@decorator[cache_key]) : @decorator[cache_key]
    end
    
    def recursively_find_decorator(version, current_klass = self)
      return if current_klass == nil
      begin
        decorators = current_klass.registered_decorators
        decorator_class = (decorators[version] || decorators[:default])
        decorator_class.constantize
      rescue
        recursively_find_decorator(version, current_klass.superclass)
      end
    end
  end

end
