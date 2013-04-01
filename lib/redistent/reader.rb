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
    end
  end
end
