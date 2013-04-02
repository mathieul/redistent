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
        models.each do |model|
          run_hooks(:before_write, model)
          model.uid ||= model_uids[model]
          uid_key(model).sadd(model.uid)
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

    def store_attributes(model, attributes)
      serialized = BSON.serialize(attributes)
      attribute_key(model).set(serialized.to_s)
      model.persisted_attributes = attributes
    end

    def model_attributes(model_references, attributes)
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
      references.each do |reference|
        persisted_value = model.persisted_attributes[reference.attribute] unless model.persisted_attributes.nil?
        value = attributes[reference.attribute]
        next if persisted_value == value
        reference_key = index_key(model, reference.attribute)
        reference_key[persisted_value].srem(model.uid) unless persisted_value.nil?
        reference_key[value].sadd(model.uid) unless value.nil?
      end
    end

    def run_hooks(name, model)
      hooks = describe(model).hooks[name]
      Array(hooks).each { |hook| model.send(hook) }
    end
  end
end
