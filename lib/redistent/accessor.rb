require "redis"
require "nest"

module Redistent
  module Accessor
    def self.included(base)
      base.instance_eval do
        extend ClassMethods
        def config
          @config ||= Config.new
        end
      end
    end

    attr_reader :key

    module ClassMethods
      def model(name, &block)
        config.add_model(name, &block)
      end

      def before_write(message)
        config.add_hook(:before_write, message)
      end
    end

    def initialize(config)
      redis = Redis.new(config)
      @key = Nest.new("redistent", redis)
    end

    def write(*args)
      writer.write(*args)
    end

    def read(*args)
      reader.read(*args)
    end

    def erase(*args)
      eraser.erase(*args)
    end

    def collection(*args)
    end

    private

    def writer
      @writer ||= Writer.new(key, self.class.config.models)
    end

    def reader
      @reader ||= Reader.new(key, self.class.config.models)
    end

    def eraser
      @eraser ||= Eraser.new(key, self.class.config.models)
    end
  end
end
