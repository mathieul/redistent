module Redistent
  class Config
    attr_reader :current_model, :current_collection

    ModelDescription = Struct.new(
      :name, :persist_attributes, :hooks, :references, :collections
    )
    ReferenceDescription = Struct.new(
      :model, :attribute
    )
    CollectionDescription = Struct.new(
      :model, :type, :sort_by, :attribute, :target, :target_attribute, :methods
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

    def add_model(name, &block)
      definition = models[name] ||= ModelDescription.new(name, true, hooks, [], [])
      with_model(definition, &block) if block_given?
      definition
    end

    def references(name)
      reference = ReferenceDescription.new(name, :"#{name}_uid")
      current_model.references << reference
      add_implicit_collection(name, current_model.name)
    end

    def add_implicit_collection(model_name, collection_name)
      model = add_model(model_name) unless model = models[model_name]
      collection = model.collections.find { |item| item.model == collection_name }
      unless collection
        model.collections << CollectionDescription.new(
          collection_name, :referenced, nil, :"#{model_name}_uid"
        )
      end
    end

    def embeds(name, sort_by: false, &block)
      singular_name = name.to_s.singularize.to_sym
      collection = CollectionDescription.new(
        singular_name, :embedded, sort_by, :"#{singular_name}_uid"
      )
      if block_given?
        collection.methods = {}
        with_collection(collection, &block)
      end
      current_model.collections << collection
    end

    def collection(name, via: nil)
      singular_name = name.to_s.singularize.to_sym
      collection = CollectionDescription.new(
        singular_name, :referenced, nil, :"#{singular_name}_uid"
      )
      unless via.nil?
        model, attribute = collection.model, collection.attribute
        collection.model = via.to_s.singularize.to_sym
        collection.attribute = :"#{collection.model}_uid"
        collection.target, collection.target_attribute = model, attribute
      end
      current_model.collections << collection
    end

    def define(name, &block)
      current_collection.methods[name] = block
    end

    private

    def with_model(model, &block)
      old_model = @current_model
      @current_model = model
      instance_eval(&block)
      @current_model = old_model
    end

    def with_collection(collection, &block)
      old_collection = @current_collection
      @current_collection = collection
      instance_eval(&block)
      @current_collection = old_collection
    end
  end
end
