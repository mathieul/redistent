require "bson"

module Redistent
  class Reader
    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
      @descriptions = {}
    end

    def read(model_type, uid)
      class_name = model_type.to_s.camelize
      serialized = key[class_name][uid].get
      raise ModelNotFound, "No model foudn with uid #{uid.inspect}" if serialized.nil?
      attributes = BSON.deserialize(serialized)
      klass = Object.const_get(class_name.to_sym)
      klass.new(attributes.merge(uid: uid)).tap do |model|
        model.persisted_attributes = model.attributes
      end
    end

    private

    def model_key(model)
      key[model.class.to_s]
    end
  end
end
