module Redistent
  module Accessor
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def model(*args)
      end

      def before_write(*args)
      end
    end
  end
end
