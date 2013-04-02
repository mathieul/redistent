module Redistent
  module HasModelDescriptions
    def describe(model)
      @descriptions ||= {}
      @descriptions[model.class] ||= begin
        type = model.class.to_s.underscore.to_sym
        unless (description = models[type])
          raise ConfigError, "Model #{type.inspect} hasn't been described"
        end
        description
      end
    end
  end
end
