require "bson"

module Redistent
  class Eraser
    include HasModelKeys
    include HasModelDescriptions

    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
    end

    def erase(model)
      uid_key(model).srem(model.uid)
      attribute_key(model).del
      attributes = model.persisted_attributes
      describe(model).references.each do |reference|
        cleanup_indices(model, reference)
      end
    end

    private

    def cleanup_indices(model, reference)
      return if model.persisted_attributes.nil?
      if (ref_uid = model.persisted_attributes[reference.attribute])
        index_key(model, reference.attribute)[ref_uid].srem(model.uid)
        reference_key(model, reference.attribute).del
        collection = reference.collection
        if collection.type == :sorted
          sorted = sorted_key(reference.model, ref_uid, collection.attribute)
          sorted.zrem(model.uid)
        end
      end
    end
  end
end
