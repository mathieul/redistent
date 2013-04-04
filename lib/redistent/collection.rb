module Redistent
  class Collection
    attr_reader :model, :key, :locker, :description

    def initialize(key, model, locker, description)
      @key         = key
      @model       = model
      @locker      = locker
      @description = description
    end
  end
end
