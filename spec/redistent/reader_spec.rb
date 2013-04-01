require "spec_helper"
require "music_classes"
require "redis_helper"

describe Redistent::Reader do
  include RedisHelper

  let(:key)       { Nest.new("reader", redis) }
  let(:reader)    { Redistent::Reader.new(key, config.models) }

  context "read simple model" do
    it "finds a model by uid" do
      redis.set("reader:Band:12", BSON.serialize({}).to_s)
      model = reader.read(:band, "12")
      expect(model).to be_an_instance_of(Band)
    end

    it "reads attributes from storage" do
      serialized = BSON.serialize("name" => "Eiffel")
      redis.set("reader:Band:42", serialized.to_s)
      model = reader.read(:band, "42")
      expect(model.uid).to eq("42")
      expect(model.name).to eq("Eiffel")
    end

    it "remembers the persisted attributes" do
      serialized = BSON.serialize("name" => "Eiffel")
      redis.set("reader:Band:42", serialized.to_s)
      model = reader.read(:band, "42")
      model.name = "Noir Désir"
      expect(model.attributes).to eq(name: "Noir Désir")
      expect(model.persisted_attributes).to eq(name: "Eiffel")
    end

    it "raises an error if no model was found with this uid" do
      expect { reader.read(:band, "doesn-t-exist") }.to raise_error(Redistent::ModelNotFound)
    end
  end
end
