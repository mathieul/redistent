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
      unless (serialized = key[class_name][uid].get)
        raise ModelNotFound, "No model foudn with uid #{uid.inspect}"
      end
      attributes = deserialize_attributes(serialized)
      references = models[model_type].references
      attributes = replace_uids_with_instances!(references, attributes)
      klass = Object.const_get(class_name.to_sym)
      klass.new(attributes.merge(uid: uid)).tap do |model|
        model.persisted_attributes = model.attributes
      end
    end

    private

    def model_key(model)
      key[model.class.to_s]
    end

    def deserialize_attributes(serialized)
      BSON.deserialize(serialized).each.with_object({}) do |(name, value), attributes|
        attributes[name.to_sym] = value
      end
    end

    def replace_uids_with_instances!(references, attributes)
      references.each do |reference|
        uid = attributes.delete(reference.attribute)
        next unless uid
        attributes[reference.model] = read(reference.model, uid)
      end
      attributes
    end
  end
end
