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

    def next_uid
      key["next_uid"].incr.to_s
    end

    private

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
        cleanup_reference_index(model, reference)
        populate_reference_index(model, attributes, reference)
        collection = reference.collection
        if collection.type == :sorted
          cleanup_sorted_index(model, reference, collection)
          populate_sorted_index(model, reference, collection)
        end
      end
    end

    def cleanup_reference_index(model, reference)
      return if model.persisted_attributes.nil?
      attribute_name = reference.attribute
      if (target_uid = model.persisted_attributes[attribute_name])
        the_key = index_key(model, attribute_name)
        the_key[target_uid].srem(model.uid)
      end
    end

    def populate_reference_index(model, attributes, reference)
      target_uid = attributes[reference.attribute]
      unless target_uid.nil?
        the_key = index_key(model, reference.attribute)
        the_key[target_uid].sadd(model.uid)
      end
      reference_key(model, reference.attribute).set(target_uid)
    end

    def cleanup_sorted_index(model, reference, collection)
      return if model.persisted_attributes.nil?
      if (target_uid = model.persisted_attributes[reference.attribute])
        the_key = sorted_key(reference.model, target_uid, collection.attribute)
        the_key.zrem(model.uid)
      end
    end

    def populate_sorted_index(model, reference, collection)
      if (referenced = model.public_send(reference.model))
        the_key = sorted_key(reference.model, referenced.uid, collection.attribute)
        score = model.public_send(collection.sort_by).to_f
        the_key.zadd(score, model.uid)
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
