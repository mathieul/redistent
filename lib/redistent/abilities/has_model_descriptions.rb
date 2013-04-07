require "inflecto"

module Redistent
  module HasModelDescriptions
    def describe(model)
      @descriptions ||= {}
      @descriptions[model.class] ||= begin
        model_name = model.class.to_s.split("::").last
        type = Inflecto.underscore(model_name).to_sym
        unless (description = models[type])
          raise ConfigError, "Model #{type.inspect} hasn't been described"
        end
        description
      end
    end
  end
end
