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
          model.uid ||= model_uids[model]
          model_key = key[model.class.to_s]
          push_uid(model_key, model)
          store_attributes(model_key, model)
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
        Array(describe(model).references).each do |reference|
          referenced = attributes[reference.model]
          found[referenced] = next_uid if referenced.uid.nil?
        end
      end
    end

    def next_uid
      key["next_uid"].incr.to_s
    end

    private

    def push_uid(model_key, model)
      model_key["all"].sadd(model.uid)
    end

    def store_attributes(model_key, model)
      attributes = model_attributes(model)
      serialized = BSON.serialize(attributes)
      model_key[model.uid].set(serialized.to_s)
    end

    def describe(model)
      @descriptions[model.class] ||= begin
        model_type = model.class.to_s.underscore.to_sym
        unless (description = models[model_type])
          raise ConfigError, "Model #{model_type.inspect} hasn't been described"
        end
        description
      end
    end

    def model_attributes(model)
      replace_references_with_uids(describe(model).references, model.attributes)
    end

    def replace_references_with_uids(model_references, attributes)
      Array(model_references).each do |reference|
        if attributes.has_key?(reference.model)
          referenced = attributes.delete(reference.model)
          write(referenced)
          attributes[reference.attribute] = referenced.uid
        end
      end
      attributes
    end
  end
end
