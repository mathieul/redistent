module Redistent
  class Config
    attr_reader :hooks, :models, :current_model, :current_collection

    def add_hook(name, message)
      @hooks ||= {}
      (@hooks[name] ||= []) << message
    end

    def add_model(name, &block)
      @models ||= {}
      definition = @models[name] ||= {}
      definition[:persist_attributes] = true
      with_model(definition, &block) if block_given?
    end

    def references(name)
      reference = {model: name, attribute: :"#{name}_id"}
      (current_model[:references] ||= []) << reference
    end

    def embeds(name, sort_by: false, &block)
      singular_name = name.to_s.singularize.to_sym
      collection = {
        type: :embedded,
        sort_by: sort_by,
        model: singular_name,
        attribute: :"#{singular_name}_id"
      }
      if block_given?
        collection[:methods] = {}
        with_collection(collection, &block)
      end
      (current_model[:collections] ||= []) << collection
    end

    def collection(name, via: nil)
      singular_name = name.to_s.singularize.to_sym
      collection = {
        type: :referenced,
        model: singular_name,
        attribute: :"#{singular_name}_id"
      }
      unless via.nil?
        singular_via = via.to_s.singularize.to_sym
        collection.merge!(
          target: collection[:model], target_attribute: collection[:attribute],
          model: singular_via, attribute: :"#{singular_via}_id"
        )
      end
      (current_model[:collections] ||= []) << collection
    end

    def define(name, &block)
      current_collection[:methods][name] = block
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
