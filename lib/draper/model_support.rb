module Draper::ModelSupport
  extend ActiveSupport::Concern

  def decorator(options = {})
    cache_key = options.flatten.join.parameterize
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
      @decorator ||= {}
      @decorator[cache_key] ||= begin
        decorator_version = options[:version] || :default
        decorator_class = self.recursively_find_decorator(decorator_version)
        decorator_class.decorate(self.scoped, options) if decorator_class
      end
      block_given? ? yield(@decorator[cache_key]) : @decorator[cache_key]
    end
    
    def recursively_find_decorator(version)
      current_klass, decorator_class = self, nil
      while current_klass != nil && decorator_class.blank?
        decorators = current_klass.registered_decorators
        next unless decorators
        decorator_class = (decorators[version] || decorators[:default])
        return decorator_class.constantize if decorator_class.present?
        current_klass = current_klass.superclass
      end
    end
  end

end
