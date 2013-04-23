require "inflecto"

module Redistent
  class Config
    attr_reader :current_model

    Model = Struct.new(:name, :config, :indices) do
      def hooks
        config.hooks
      end
      def namespace
        config.namespace
      end
      def collections
        @collections ||= {}
      end
    end

    Index = Struct.new(:model, :attribute, :inline_reference)

    Collection = Struct.new(
      :name, :model
    )

    def hooks
      @hooks ||= {}
    end

    def models
      @models ||= {}
    end

    def namespace
      @namespace ||= Object
    end

    def add_hook(name, &block)
      hook = block || ->{}
      (hooks[name] ||= []) << hook
    end

    def add_model(singular_name, &block)
      definition = models[singular_name] ||= Model.new(singular_name, self, [])
      with_model(definition, &block) if block_given?
      definition
    end

    def set_namespace(the_module)
      @namespace = the_module
    end

    def index(singular_name, options = {})
      current_model.indices << Index.new(
        singular_name,
        :"#{singular_name}_uid",
        !!options[:inline_reference]
      )
    end

    def collection(name, options = {})
      model = options.fetch(:model) { Inflecto.singularize(name).to_sym }
      collection = Collection.new(name, model)
      current_model.collections[name] = collection
      # singular_name = Inflecto.singularize(plural_name).to_sym
      # collection = Collection.new(
      #   singular_name,
      #   collection_type(via, sort_by),
      #   :"#{singular_name}_uid",
      #   sort_by
      # )
      # if collection.type == :sorted
      #   collection.attribute = Inflecto.pluralize(collection.attribute).to_sym
      # end
      # add_indirection_to_collection(collection, via) unless via.nil?
      # current_model.collections[plural_name] = collection
    end

    def finalize!
      return if @finalized
      models.each do |model_name, model|
        plural_name = Inflecto.pluralize(model_name).to_sym
        model.indices.each do |reference|
          unless (reference_model = models[reference.model])
            raise ConfigError, "Model #{type.inspect} hasn't been described"
          end
          reference.collection = reference_model.collections[plural_name]
          reference.collection.reference = reference
        end
      end
      @finalized = true
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
      collection.model = Inflecto.singularize(via).to_sym
      collection.attribute = :"#{current_model.name}_uid"
      collection.target, collection.target_attribute = model, attribute
    end

    def with_model(model, &block)
      old_model = @current_model
      @current_model = model
      instance_eval(&block)
      @current_model = old_model
    end
  end
end
