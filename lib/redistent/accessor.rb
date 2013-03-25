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

      def before_write(message)
        config.add_hook(:before_write, message)
      end
    end
  end
end
