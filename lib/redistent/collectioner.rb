module Redistent
  class Collectioner
    include HasModelDescriptions

    attr_reader :models, :key, :locker

    def initialize(key, models, locker)
      @key    = key
      @models = models
      @locker = locker
    end

    def collection(model, plural_name)
      description = describe(model)
      singular_name = plural_name.to_s.singularize.to_sym
      collection = description.collections.find { |item| item.model == singular_name }
      if collection.nil?
        raise ConfigError, "collection #{plural_name.inspect} not found for #{model.class}."
      end
      Collection.new(model, key, locker, collection)
    end
  end
end
