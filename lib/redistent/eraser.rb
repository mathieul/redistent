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
        if (ref_uid = attributes[reference.attribute])
          index_key(model, reference.attribute)[ref_uid].srem(model.uid)
          reference_key(model, reference.attribute).del
        end
      end
    end
  end
end
