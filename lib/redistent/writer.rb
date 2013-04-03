require "bson"

module Redistent
  class Writer
    include HasModelKeys
    include HasModelDescriptions

    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
    end

    def write(*models)
      model_uids = set_and_return_missing_uids(models)
      key.redis.multi do
        model_uids.each { |model, uid| model.uid = uid }
        models.each { |model| write_model(model, model.uid || uid) }
      end
    rescue Exception => ex
      model_uids.each { |model, uid| model.uid = nil } unless model_uids.nil?
      raise ex
    end

    def set_and_return_missing_uids(models, found = {})
      Array(models).each do |model|
        found[model] = next_uid if model.uid.nil?
        attributes = model.attributes
        describe(model).references.each do |reference|
          if (referenced = attributes[reference.model])
            found = set_and_return_missing_uids(referenced, found)
          end
        end
      end
      found
    end

    def next_uid
      key["next_uid"].incr.to_s
    end

    private

    def write_model(model, uid)
      run_hooks(:before_write, model)
      model.uid = uid
      uid_key(model).sadd(model.uid)
      references = describe(model).references
      attributes = model_attributes(references, model.attributes)
      index_reference_indices(model, references, attributes)
      store_attributes(model, attributes)
    end

    def store_attributes(model, attributes)
      serialized = BSON.serialize(attributes)
      attribute_key(model).set(serialized.to_s)
      model.persisted_attributes = attributes
    end

    def model_attributes(model_references, attributes)
      model_references.each do |reference|
        if (referenced = attributes.delete(reference.model))
          write(referenced)
          attributes[reference.attribute] = referenced.uid
        end
      end
      attributes
    end

    def index_reference_indices(model, references, attributes)
      references.each do |reference|
        cleanup_reference_index(model, reference.attribute)
        populate_reference_index(model, reference.attribute, attributes)
      end
    end

    def cleanup_reference_index(model, attribute_name)
      return if model.persisted_attributes.nil?
      if (value = model.persisted_attributes[attribute_name])
        reference_key = index_key(model, attribute_name)
        reference_key[value].srem(model.uid)
      end
    end

    def populate_reference_index(model, attribute_name, attributes)
      if (value = attributes[attribute_name])
        reference_key = index_key(model, attribute_name)
        reference_key[value].sadd(model.uid)
      end
    end

    def run_hooks(name, model)
      hooks = describe(model).hooks[name]
      Array(hooks).each do |hook|
        hook.respond_to?(:call) ? hook.call(model) : model.send(hook)
      end
    end
  end
end
