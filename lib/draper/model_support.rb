module Draper::ModelSupport
  extend ActiveSupport::Concern

  def decorator(options = {})
    cache_key = options.flatten.join.parameterize
    @decorator ||= {}
    @decorator[cache_key] ||= begin
      decorator_version = options[:version] || :default
      decorators = self.class.registered_decorators
      decorator_class = (decorators[decorator_version] || decorators[:default]).constantize
      decorator_class.new(self, options)
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
        decorators = self.registered_decorators
        decorator_class = (decorators[decorator_version] || decorators[:default]).constantize
        decorator_class.decorate(self.scoped, options)
      end
      block_given? ? yield(@decorator[cache_key]) : @decorator[cache_key]
    end
  end

end
