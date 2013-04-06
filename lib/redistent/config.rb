module Redistent
  class Config
    attr_reader :current_model

    ModelDescription = Struct.new(
      :name, :persist_attributes, :hooks, :references, :collections
    )
    ReferenceDescription = Struct.new(
      :model, :attribute
    )
    CollectionDescription = Struct.new(
      :model, :type, :attribute, :sort_by, :target, :target_attribute
    )

    def hooks
      @hooks ||= {}
    end

    def models
      @models ||= {}
    end

    def add_hook(name, message = nil, &block)
      hook = message ? message : (block || ->{})
      (hooks[name] ||= []) << hook
    end

    def add_model(singular_name, &block)
      definition = models[singular_name] ||= ModelDescription.new(singular_name, true, hooks, [], {})
      with_model(definition, &block) if block_given?
      definition
    end

    def references(singular_name)
      reference = ReferenceDescription.new(singular_name, :"#{singular_name}_uid")
      current_model.references << reference
      add_implicit_collection(singular_name, current_model.name)
    end

    def collection(plural_name, via: nil, sort_by: nil)
      singular_name = plural_name.to_s.singularize.to_sym
      collection = CollectionDescription.new(
        singular_name,
        collection_type(via, sort_by),
        :"#{singular_name}_uid",
        sort_by
      )
      if collection.type == :sorted
        collection.attribute = collection.attribute.to_s.pluralize.to_sym
      end
      add_indirection_to_collection(collection, via) unless via.nil?
      current_model.collections[plural_name] = collection
    end

    private

    def collection_type(via, sort_by)
      unless via.nil? or sort_by.nil?
        raise ConfigError, "Can't declare a collection using both :via and :sort_by"
      end
      return :sorted if sort_by
      return :indirect if via
      :referenced
    end

    def add_indirection_to_collection(collection, via)
      model, attribute = collection.model, collection.attribute
      collection.model = via.to_s.singularize.to_sym
      collection.attribute = :"#{current_model.name}_uid"
      collection.target, collection.target_attribute = model, attribute
    end

    def with_model(model, &block)
      old_model = @current_model
      @current_model = model
      instance_eval(&block)
      @current_model = old_model
    end

    def add_implicit_collection(model_name, collection_name)
      model = add_model(model_name) unless model = models[model_name]
      plural_name = collection_name.to_s.pluralize.to_sym
      model.collections[plural_name] ||= CollectionDescription.new(
        collection_name, :referenced, :"#{model_name}_uid"
      )
    end
  end
end
