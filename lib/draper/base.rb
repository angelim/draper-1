module Draper
  class Base
    require 'active_support/core_ext/class/attribute'
    include Draper::JsonHelper
    class_attribute :denied, :allowed, :model_class
    attr_accessor :context, :model, :version

    DEFAULT_DENIED = Object.new.methods << :method_missing
    FORCED_PROXY = [:to_param, :id]
    FORCED_PROXY.each do |method|
      define_method method do |*args, &block|
        model.send method, *args, &block
      end
    end
    self.denied = DEFAULT_DENIED

    # Initialize a new decorator instance by passing in
    # an instance of the source class. Pass in an optional
    # context inside the options hash is stored for later use.
    #
    # @param [Object] instance to wrap
    # @param [Hash] options (optional)
    def initialize(input, options = {})
      input.inspect # forces evaluation of a lazy query from AR
      self.class.model_class = input.class if model_class.nil?
      @model = input
      self.context = options.fetch(:context, {})
      self.version = options.fetch(:version, :default)
    end

    # Proxies to the class specified by `decorates` to automatically
    # lookup an object in the database and decorate it.
    #
    # @param [Symbol or String] id to lookup
    # @return [Object] instance of this decorator class
    def self.find(input, options = {})
      model_class.find(input).decorate(options)
    end

    # Typically called within a decorator definition, this method
    # specifies the name of the wrapped object class.
    #
    # For instance, a `ProductDecorator` class might call `decorates :product`
    #
    # But they don't have to match in name, so a `EmployeeDecorator`
    # class could call `decorates :person` to wrap instances of `Person`
    #
    # This is primarilly set so the `.find` method knows which class
    # to query.
    #
    # @param [ Symbol ] input Snakecase name of the decorated class, like `:product`
    # @param options [ Symbol ] :class Usefull when using namespaced classes or some class alias
    # @param options [ Symbol ] :version An Alternative decorator version
    # @raise ArgumentError When using unconventional decorator naming without providing a :version name
    # 
    # @example A decorator for a namespaced class +User::Profile+
    #   class ProfileDecorator < ApplicationDecorator
    #     decorates :profile, :class => User::Profile
    #   end
    # 
    # @example A default decorator for +Product+
    #   class ProductDecorator < ApplicationDecorator
    #     decorates :product
    #     def name
    #       "#{id}-#{name}"
    #     end
    #   end
    #   p = Product.new(:name => "Vanilla")
    #   p.id #=> 1
    #   p.decorator.name #=> 1-Vanilla
    # 
    # @example A special decorator for +Product+
    #   class Api::ProductDecorator < ApplicationDecorator
    #     decorates :product, :version => :api
    #     def name
    #       "api-#{id}-#{name}"
    #     end
    #   end
    #   p = Product.new(:name => "Vanilla")
    #   p.id #=> 1
    #   p.decorator.name #=> api-1-Vanilla
    def self.decorates(input, options = {})
      @options = options
      self.model_class = @options[:class] || input.to_s.camelize.constantize
      inferred_decorator_name = "#{self.model_class}Decorator"
      if version = @options[:version]
        decorator_version = { version => self.name }
      elsif version.blank? && self.name == inferred_decorator_name
        decorator_version = { :default => inferred_decorator_name }
      else
        raise ArgumentError, "Specify a :version option for decorators that doen't follow basic naming conventions"
      end
      unless defined? self.model_class.registered_decorators
        initialize_decorator_registration
      end
      self.registered_decorators ||= {}
      self.registered_decorators.merge!(decorator_version)
      define_method(input){ @model }
    end
    
    # Defines a class variable to hold all versions of related decorators
    # and includes +Drapper::ModelSupport+ methods in +model_class+.
    # @see .decorates
    # @see Drapper::ModelSupport
    def self.initialize_decorator_registration
      self.model_class.class_eval <<-RUBY
        class << self
          attr_accessor :registered_decorators
        end
      RUBY
      model_class.send :include, Draper::ModelSupport
    end

    # Specifies a black list of methods which may *not* be proxied to
    # to the wrapped object.
    #
    # Do not use both `.allows` and `.denies` together, either write
    # a whitelist with `.allows` or a blacklist with `.denies`
    #
    # @param [Symbols*] methods to deny like `:find, :find_by_name`
    def self.denies(*input_denied)
      raise ArgumentError, "Specify at least one method (as a symbol) to exclude when using denies" if input_denied.empty?
      raise ArgumentError, "Use either 'allows' or 'denies', but not both." if self.allowed?
      self.denied += input_denied
    end

    # Specifies a white list of methods which *may* be proxied to
    # to the wrapped object. When `allows` is used, only the listed
    # methods and methods defined in the decorator itself will be
    # available.
    #
    # Do not use both `.allows` and `.denies` together, either write
    # a whitelist with `.allows` or a blacklist with `.denies`
    #
    # @param [Symbols*] methods to allow like `:find, :find_by_name`
    def self.allows(*input_allows)
      raise ArgumentError, "Specify at least one method (as a symbol) to allow when using allows" if input_allows.empty?
      raise ArgumentError, "Use either 'allows' or 'denies', but not both." unless (self.denied == DEFAULT_DENIED)
      self.allowed = input_allows
    end

    # Initialize a new decorator instance by passing in
    # an instance of the source class. Pass in an optional
    # context into the options hash is stored for later use.
    #
    # When passing in a single object, using `.decorate` is
    # identical to calling `.new`. However, `.decorate` can
    # also accept a collection and return a collection of
    # individually decorated objects.
    #
    # @param [Object] instance(s) to wrap
    # @param [Hash] options (optional)
    def self.decorate(input, options = {})
      if input.respond_to?(:each)
        Draper::DecoratedEnumerableProxy.new(input, self, options)
      elsif input.respond_to? :decorate
        input.decorate(options)
      else
        new(input, options)
      end
    end
    
    # Typically called withing a decorator definition, this method causes
    # the assocation to be decorated when it is retrieved.
    #
    # @param [Symbol] name of association to decorate, like `:products`
    def self.decorates_association(association_symbol, options = {})
      define_method(association_symbol) do
        orig_association = model.send(association_symbol)
        orig_association.decorate(options.reverse_merge(:version => version)) if orig_association
      end
    end

    # A convenience method for decorating multiple associations. Calls
    # decorates_association on each of the given symbols.
    #
    # @param [Symbols*] name of associations to decorate
    def self.decorates_associations(*association_symbols)
      association_symbols.each{ |sym| decorates_association(sym) }
    end
    
    # Fetch all instances of the decorated class and decorate them.
    #
    # @param [Hash] options (optional)
    # @return [Draper::DecoratedEnumerableProxy]
    def self.all(options = {})
      Draper::DecoratedEnumerableProxy.new(model_class.all, self, options)
    end

    def self.first(options = {})
      model_class.first.decorate(options)
    end

    def self.last(options = {})
      model_class.last.decorate(options)
    end

    # Access the helpers proxy to call built-in and user-defined
    # Rails helpers. Aliased to `.h` for convinience.
    #
    # @return [Object] proxy
    def helpers
      self.class.helpers
    end
    alias :h :helpers

    # Access the helpers proxy to call built-in and user-defined
    # Rails helpers from a class context.
    #
    # @return [Object] proxy
    class << self
      def helpers
        Draper::ViewContext.current
      end
      alias :h :helpers
    end

    # Fetch the original wrapped model.
    #
    # @return [Object] original_model
    def to_model
      @model
    end

    # Delegates == to the decorated models
    #
    # @return [Boolean] true if other's model == self's model
    def ==(other)
      @model == (other.respond_to?(:model) ? other.model : other)
    end

    def kind_of?(klass)
      super || model.kind_of?(klass)
    end
    
    def is_a?(klass)
      super || model.kind_of?(klass)
    end

    def respond_to?(method, include_private = false)
      super || (allow?(method) && model.respond_to?(method))
    end

    def method_missing(method, *args, &block)
      if allow?(method)
        self.class.send :define_method, method do |*args, &block|
          model.send(method, *args, &block)
        end
        self.send(method, *args, &block)
      else
        super
      end
    end

    def self.method_missing(method, *args, &block)
      model_class.send(method, *args, &block)
    end

    def self.respond_to?(method, include_private = false)
      super || model_class.respond_to?(method)
    end

  private
    def allow?(method)
      (!allowed? || allowed.include?(method) || FORCED_PROXY.include?(method)) && !denied.include?(method)
    end
  end
end
