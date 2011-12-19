module Draper
  # This module provides better support for json generation, either for single
  # decorator object, as for a collection of decorated objects.
  # Introduces two new options to regular ActiveSupport json options, named
  # :decorated_methods and :decorated_include
  # :decorated_methods are methods defined in a decorator
  #   to be appended to json. This is specially useful for situations where it is
  #   preferrable to present a model attribute in a alternative format
  #   using existing helpers. 
  # :decorated_include includes relations that will
  #   render json based on their respective Decorator default options
  # Refer to #as_decorated_json for examples
  # @note Heavily inspired on Mongoid's serialization implementation
  # @see https://github.com/mongoid/mongoid/blob/master/lib/mongoid/serialization.rb
  module JsonHelper
    extend ActiveSupport::Concern
    
    # Returns json representation for a record node when generating
    # json from DecoratedEnumerableProxy
    def as_json(options = {})
      as_decorated_json(options)
    end
    
    # Point single record json generation to #as_json
    # @see #as_json
    def to_json(options = {})
      as_json(options)
    end

    # Extends uppon +ActiveModel::Serialization::SerializableHash+
    # to add decorator options.
    # @param [ Hash ] options The serialization options.
    # @param options [ Array<Symbol> ] :decorated_methods Methods defined in decorator
    #   to be appended to json. This is specially useful for situations where it is
    #   preferrable to present a model attribute in a alternative format
    #   using existing helpers.
    # @param options [ Array<Symbol> ] :decorated_include Included relations that will
    #   render json based on their respective Decorator options
    # @return [ String ] object in json format
    # @note To provide default options to the decorated json, override #as_json
    #   calling #as_decorated_json to benefit from extended options. This will work both
    #   single records and collections.
    # @example Defining default options to decorated json
    #   class ProductDecorator < Draper::Base
    #     def as_json(options = {})
    #       as_decorated_json(options.merge(:only => [:name]))
    #     end
    #   end
    # @example Defining a custom method in decorator to extend model attributes
    #   class ProductDecorator < Draper::Base
    #     decorates :product
    #     def price
    #       h.number_to_currency(product.price)
    #     end
    #   end
    #   original_json = Product.first.decorate.to_json
    #   original_json #=> {"id" => "1", "price" => "4.45"}
    #   decorated_json = Product.first.decorate.to_json(:decorated_methods => [:price])
    #   decorated_json #=> {"id" => "1", "price" => "$4.45"}
    # 
    # @example Including decorated associations
    #   class StoreDecorator < Draper::Base
    #     def name
    #       "Formatted Name"
    #     end
    #     def as_json(options = {})
    #       as_decorated_json(options.merge(:decorated_methods => [:name], :only => [:location]))
    #     end
    #   end
    #   class ProductDecorator < Draper::Base
    #     decorates :product
    #     decorates_association :store
    #   end
    #   original_json = Product.first.decorate.to_json(:include => :store)
    #   original_json #=> {"id" => "1", "price" => "4.45", :store => {"id" => "1", "name" => "Original Name", "location" => "Disney"} }
    #   decorated_json = Product.first.decorate.to_json(:decorated_include => :store)
    #   decorated_json #=> {"id" => "1", "price" => "$4.45", :store => {"name" => "Formatted Name", "location" => "Disney"}}
    # @see ActiveModel::Serialization::SerializableHash
    def as_decorated_json(options = {})
      model.as_json(options).merge(decorated_attributes(options)).to_json
    end
    
    # @param #as_decorated_json
    def decorated_attributes(options = {})
      method_names = Array.wrap(options[:decorated_methods]).map { |n| n.to_s if respond_to?(n.to_s) }.compact
      Hash[method_names.map { |n| [n, send(n)] }].tap do |attrs|
        decorate_relations(attrs, options) if options[:decorated_include]
      end
    end
    
    # Decorates relations with default options defined in their respective
    #   decorators and adds nodes to attributes
    # @param [ Hash ] attributes The attributes to serialize.
    # @param [ Hash ] options (see #as_decorated_json)
    # @return [ Hash ] The document, ready to be serialized.
    def decorate_relations(attributes = {}, options = {})
      inclusions = options[:decorated_include]
      relation_names(inclusions).each do |name|
        metadata = relations[name.to_s]
        relation = send(metadata.name)
        if relation
          attributes[metadata.name.to_s] =
            relation.as_json(relation_options(inclusions, options, name))
        end
      end
    end
    
    # Since the inclusions can be a hash, symbol, or array of symbols, this is
    # provided as a convenience to parse out the names.
    # @param [ Hash, Symbol, Array<Symbol ] inclusions The inclusions.
    # @return [ Array<Symbol> ] The names of the included relations. 
    def relation_names(inclusions)
      inclusions.is_a?(Hash) ? inclusions.keys : Array.wrap(inclusions)
    end

    # Since the inclusions can be a hash, symbol, or array of symbols, this is
    # provided as a convenience to parse out the options.
    # @param [ Hash, Symbol, Array<Symbol ] inclusions The inclusions.
    # @param [ Symbol ] name The name of the relation.
    # @return [ Hash ] The options for the relation.
    def relation_options(inclusions, options, name)
      if inclusions.is_a?(Hash)
        inclusions[name]
      else
        { :except => options[:except], :only => options[:only] }
      end
    end
  end
end
