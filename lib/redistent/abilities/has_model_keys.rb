module Redistent
  module HasModelKeys
    def model_key(model)
      model_name = model.is_a?(Symbol) ? model.to_s.camelize : model.class.to_s
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
  end
end
