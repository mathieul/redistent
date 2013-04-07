require "spec_helper"
require "music_classes"
require "redis_helper"

module ReaderSpecHelper
  class NamespacedModel
    include Virtus
    attr_accessor :uid, :persisted_attributes
    attribute :name, String
  end
end

describe Redistent::Reader do
  include RedisHelper

  let(:key)       { Nest.new("reader", redis) }
  let(:reader)    { Redistent::Reader.new(key, config.models) }

  context "read simple model" do
    it "finds a model by uid" do
      redis.set("reader:Band:12", BSON.serialize({}).to_s)
      model = reader.read(:band, "12")
      expect(model).to be_an_instance_of(MusicClasses::Band)
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

    it "uses the namespace to infer model classes" do
      config.set_namespace ReaderSpecHelper
      config.add_model :namespaced_model
      redis.set("reader:NamespacedModel:99", BSON.serialize({}).to_s)
      model = reader.read(:namespaced_model, "99")
      expect(model).to be_an_instance_of(ReaderSpecHelper::NamespacedModel)
    end
  end

  context "read model with references" do
    it "replaces reference uids with instance" do
      redis.set("reader:Band:42",
        BSON.serialize(name: "Eiffel").to_s
      )
      redis.set("reader:Musician:1",
        BSON.serialize(name: "Romain Humeau", band_uid: "42").to_s
      )
      romain = reader.read(:musician, "1")
      expect(romain.name).to eq("Romain Humeau")
      expect(romain.band).to be_an_instance_of(MusicClasses::Band)
      expect(romain.band.uid).to eq("42")
      expect(romain.band.name).to eq("Eiffel")
    end
  end
end
