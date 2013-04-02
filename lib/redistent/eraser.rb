require "bson"

module Redistent
  class Eraser
    attr_reader :models, :key

    def initialize(key, models)
      @key = key
      @models = models
    end

    def erase(model_or_uid)
    end
  end
end
