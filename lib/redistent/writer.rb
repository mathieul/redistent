module Redistent
  class Writer
    attr_reader :models

    def initialize(models)
      @models = models
    end

    def write(*args)
    end
  end
end
