require "nest"

module Redistent
  module Accessor
    def self.included(base)
      base.instance_eval do
        include HasModelDescriptions
        extend ClassMethods
        def config
          @config ||= Config.new
        end
      end
    end

    module ClassMethods
      def model(name, &block)
        config.add_model(name, &block)
      end

      def before_write(message = nil, &block)
        config.add_hook(:before_write, message, &block)
      end
    end

    attr_reader :key

    def initialize(config)
      @key = Nest.new("redistent", Redis.new(config))
      @mutex = Mutex.new
    end

    def with_lock
      @mutex.synchronize do
        yield if block_given?
      end
    end

    def write(*args)
      with_lock { writer.write(*args) }
    end

    def read(*args)
      with_lock { reader.read(*args) }
    end

    def erase(*args)
      with_lock { eraser.erase(*args) }
    end

    def collection(model, plural_name)
      collection = describe(model).collections[plural_name]
      if collection.nil?
        raise CollectionNotFound, "collection #{plural_name.inspect} not found for #{model.class}."
      end
      Collection.new(model, key, self, collection)
    end

    private

    def models
      self.class.config.models
    end

    def writer
      @writer ||= Writer.new(key, models)
    end

    def reader
      @reader ||= Reader.new(key, models)
    end

    def eraser
      @eraser ||= Eraser.new(key, models)
    end
  end
end
