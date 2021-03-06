require "inflecto"

module Redistent
  module HasModelKeys
    def model_key(model)
      model_name = if model.is_a?(Symbol)
                     Inflecto.camelize(model)
                   else
                    model.class.to_s.split("::").last
                   end
      key[model_name]
    end

    def uid_key(model)
      model_key(model)["all"]
    end

    def attribute_key(model)
      model_key(model)[model.uid]
    end

    def reference_key(model, attribute_name)
      attribute_key(model)[attribute_name]
    end

    def reference_keys(model, attribute_name)
      model_key(model)["*"][attribute_name]
    end

    def index_key(model, attribute_name)
      model_key(model)["indices"][attribute_name]
    end

    def sorted_key(model_type, model_uid, attributes_name)
      model_name = Inflecto.camelize(model_type)
      key[model_name][model_uid][attributes_name]
    end
  end
end
