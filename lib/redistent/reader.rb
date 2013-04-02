require "bson"

module Redistent
  class Reader
    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
    end

    def read(model_type, uid)
      class_name = model_type.to_s.camelize
      klass = Object.const_get(class_name.to_sym)
      attributes = read_attributes(class_name, uid)
      attributes = replace_uids_with_instances!(model_type, attributes)
      klass.new(attributes.merge(uid: uid)).tap do |model|
        model.persisted_attributes = model.attributes
      end
    end

    private

    def read_attributes(class_name, uid)
      unless (serialized = key[class_name][uid].get)
        raise ModelNotFound, "No #{class_name} found with uid #{uid.inspect}"
      end
      BSON.deserialize(serialized).each.with_object({}) do |(name, value), attributes|
        attributes[name.to_sym] = value
      end
    end

    def replace_uids_with_instances!(model_type, attributes)
      references = models[model_type].references
      references.each do |reference|
        uid = attributes.delete(reference.attribute)
        next unless uid
        attributes[reference.model] = read(reference.model, uid)
      end
      attributes
    end
  end
end
