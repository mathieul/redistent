module Redistent
  class Config
    attr_reader :current_model, :current_collection

    ModelDescription = Struct.new(
      :persist_attributes, :hooks, :references, :collections
    )
    ReferenceDescription = Struct.new(
      :model, :attribute
    )
    CollectionDescription = Struct.new(
      :type, :sort_by, :model, :attribute, :target, :target_attribute, :methods
    )

    def hooks
      @hooks ||= {}
    end

    def models
      @models ||= {}
    end

    def add_hook(name, message)
      (hooks[name] ||= []) << message
    end

    def add_model(name, &block)
      definition = models[name] ||= ModelDescription.new(true, hooks, [])
      with_model(definition, &block) if block_given?
    end

    def references(name)
      reference = ReferenceDescription.new(name, :"#{name}_uid")
      (current_model.references ||= []) << reference
    end

    def embeds(name, sort_by: false, &block)
      singular_name = name.to_s.singularize.to_sym
      collection = CollectionDescription.new(
        :embedded, sort_by, singular_name, :"#{singular_name}_uid"
      )
      if block_given?
        collection.methods = {}
        with_collection(collection, &block)
      end
      (current_model.collections ||= []) << collection
    end

    def collection(name, via: nil)
      singular_name = name.to_s.singularize.to_sym
      collection = CollectionDescription.new(
        :referenced, nil, singular_name, :"#{singular_name}_uid"
      )
      unless via.nil?
        model, attribute = collection.model, collection.attribute
        collection.model = via.to_s.singularize.to_sym
        collection.attribute = :"#{collection.model}_uid"
        collection.target, collection.target_attribute = model, attribute
      end
      (current_model.collections ||= []) << collection
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
