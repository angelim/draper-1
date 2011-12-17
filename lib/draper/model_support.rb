module Draper::ModelSupport
  extend ActiveSupport::Concern
  def decorator
    @decorator ||= "#{self.class.name}Decorator".constantize.decorate(self)
    block_given? ? yield(@decorator) : @decorator
  end
  
  def model
    self
  end
  
  alias :decorate :decorator

  module ClassMethods
    def decorate(context = {})
      @decorator_proxy ||= "#{model_name}Decorator".constantize.decorate(self.scoped)
      block_given? ? yield(@decorator_proxy) : @decorator_proxy
    end
  end

end
