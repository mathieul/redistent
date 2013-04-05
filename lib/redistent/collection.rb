module Redistent
  class Collection
    include HasModelKeys

    attr_reader :accessor, :model, :description

    def initialize(accessor, model, description)
      @accessor    = accessor
      @model       = model
      @description = description
    end

    def count
      if description.type == :referenced
        accessor.with_lock { collection_key.scard }
      else
        uids.length
      end
    end

    def uids
      if description.type == :referenced
        accessor.with_lock { collection_key.smembers }
      else
        accessor.with_lock {
          collection_key.sort(
            by: "nosort",
            get: reference_keys(description.model, description.target_attribute)
          )
        }
      end
    end

    def all
      model_name = description.target || description.model
      uids.map { |uid| accessor.read(model_name, uid) }
    end

    private

    def key
      accessor.key
    end

    def collection_key
      index_key(description.model, description.attribute)[model.uid]
    end
  end
end
