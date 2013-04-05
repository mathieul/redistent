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
      accessor.with_lock { collection_key.scard }
    end

    def uids
      accessor.with_lock { collection_key.smembers }
    end

    def all
      uids.map { |uid| accessor.read(description.model, uid) }
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
