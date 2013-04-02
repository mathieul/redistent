module Redistent
  module HasModelKeys
    def model_key(model)
      key[model.class.to_s]
    end

    def uid_key(model)
      model_key(model)["all"]
    end

    def attribute_key(model)
      model_key(model)[model.uid]
    end

    def index_key(model, attribute_name)
      model_key(model)["indices"][attribute_name]
    end
  end
end
