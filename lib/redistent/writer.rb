require "bson"

module Redistent
  class Writer
    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
      @descriptions = {}
    end

    def write(*models)
      model_uids = set_and_return_missing_uids(models)
      key.redis.multi do
        model_uids.each { |model, uid| model.uid = uid }
        models.each do |model|
          run_hooks(:before_write, model)
          model.uid ||= model_uids[model]
          push_uid(model)
          references = describe(model).references
          attributes = model_attributes(references, model.attributes)
          index_model_references(model, references, attributes)
          store_attributes(model, attributes)
        end
      end
    rescue Exception => ex
      model_uids.each { |model, uid| model.uid = nil } unless model_uids.nil?
      raise ex
    end

    def set_and_return_missing_uids(models)
      models.each.with_object({}) do |model, found|
        found[model] = next_uid if model.uid.nil?
        attributes = model.attributes
        describe(model).references.each do |reference|
          referenced = attributes[reference.model]
          found[referenced] = next_uid if referenced.uid.nil?
        end
      end
    end

    def next_uid
      key["next_uid"].incr.to_s
    end

    private

    def model_key(model)
      key[model.class.to_s]
    end

    def push_uid(model)
      model_key(model)["all"].sadd(model.uid)
    end

    def store_attributes(model, attributes)
      serialized = BSON.serialize(attributes)
      model_key(model)[model.uid].set(serialized.to_s)
      model.persisted_attributes = attributes
    end

    def describe(model)
      @descriptions[model.class] ||= begin
        type = model.class.to_s.underscore.to_sym
        unless (description = models[type])
          raise ConfigError, "Model #{type.inspect} hasn't been described"
        end
        description
      end
    end

    def model_attributes(references, attributes)
      replace_references_with_uids(references, attributes)
    end

    def replace_references_with_uids(model_references, attributes)
      model_references.each do |reference|
        if attributes.has_key?(reference.model)
          referenced = attributes.delete(reference.model)
          write(referenced)
          attributes[reference.attribute] = referenced.uid
        end
      end
      attributes
    end

    def index_model_references(model, references, attributes)
      key = model_key(model)["indices"]
      references.each do |reference|
        persisted_value = model.persisted_attributes[reference.attribute] unless model.persisted_attributes.nil?
        value = attributes[reference.attribute]
        next if persisted_value == value
        key[reference.attribute][persisted_value].srem(model.uid) unless persisted_value.nil?
        key[reference.attribute][value].sadd(model.uid) unless value.nil?
      end
    end

    def run_hooks(name, model)
      hooks = describe(model).hooks[name]
      Array(hooks).each { |hook| model.send(hook) }
    end
  end
end
