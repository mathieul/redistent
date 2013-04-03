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

    def write(*args)
      @mutex.synchronize { writer.write(*args) }
    end

    def read(*args)
      @mutex.synchronize { reader.read(*args) }
    end

    def erase(*args)
      @mutex.synchronize { eraser.erase(*args) }
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
