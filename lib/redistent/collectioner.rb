module Redistent
  class Collectioner
    include HasModelKeys
    include HasModelDescriptions

    attr_reader :models, :key, :locker

    def initialize(key, models, locker)
      @key    = key
      @models = models
      @locker = locker
    end
  end
end
