require "bson"

module Redistent
  class Writer
    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
    end

    def write(*models)
      assign_id_if_absent(models)
      key.redis.multi do
        models.each do |model|
          model_key = key[model.class.to_s]
          push_id(model_key, model)
          store_attributes(model_key, model)
        end
      end
    end

    private

    def next_id
      key["next_id"].incr.to_s
    end

    def assign_id_if_absent(models)
      models.each do |model|
        model.id ||= next_id
      end
    end

    def push_id(model_key, model)
      model_key["all"].sadd(model.id)
    end

    def store_attributes(model_key, model)
      serialized = BSON.serialize(model.attributes)
      model_key[model.id].set(serialized.to_s)
    end
  end
end
